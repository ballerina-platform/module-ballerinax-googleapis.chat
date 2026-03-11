// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/jballerina.java;
import ballerina/jwt;
import ballerina/log;

# Google Chat trigger listener. Receives Google Chat interaction events via
# Google Cloud Pub/Sub push subscriptions.
#
# ## How it works
#
# 1. On initialization, creates a Pub/Sub topic and push subscription
# 2. The Chat app (configured externally in Google Cloud Console) publishes
#    interaction events to the Pub/Sub topic
# 3. Pub/Sub pushes the events as HTTP POST requests to the `callbackURL`
# 4. The internal `DispatcherService` decodes and routes events to the
#    registered `ChatService` implementation
#
# ## Key difference from Gmail trigger
#
# Google Chat pushes the **full event payload** via Pub/Sub, so no secondary
# API calls are needed. Gmail only pushes a `historyId` requiring a follow-up
# `listHistory` call.
#
# ## Usage
#
# ```ballerina
# listener chat:Listener chatListener = new ({
#     auth: {
#         issuer: "my-bot@project.iam.gserviceaccount.com",
#         keyId: "abc123",
#         keyFile: "/path/to/key.pem"
#     }
# });
#
# @chat:ServiceConfig {
#     topicName: "projects/my-gcp-project/topics/my-chat-topic",
#     callbackURL: "https://my-app.example.com/webhook"
# }
# service chat:ChatService on chatListener {
#     remote function onMessage(chat:ChatEvent event) returns error? {
#         // Handle incoming message
#     }
#     // ... other event handlers
# }
# ```
@display {label: "Google Chat", iconPath: "docs/icon.png"}
public class Listener {
    private http:Listener httpListener;
    private DispatcherService dispatcherService;
    private string subscriptionResource = "";
    private final Client chatClient;

    http:Client pubSubClient;

    # Initializes the Google Chat trigger listener.
    #
    # Sets up the HTTP listener and Pub/Sub client. The Pub/Sub subscription is
    # created later in `attach()` using the `@ServiceConfig` annotation on the
    # service. The topic must already exist and be set as the connection target
    # in the Google Chat API configuration page in Google Cloud Console.
    #
    # + listenerConfig - Configuration including auth credentials
    # + listenOn - The port or HTTP listener to listen on. Defaults to port 8090.
    # + return - An error if initialization fails
    public function init(ListenerConfig listenerConfig, int|http:Listener listenOn = 8090) returns error? {
        if listenOn is http:Listener {
            self.httpListener = listenOn;
        } else {
            if listenerConfig.secureSocketConfig is http:ClientSecureSocket {
                self.httpListener = check new (listenOn, secureSocket = {
                    key: {
                        certFile: "",
                        keyFile: ""
                    }
                });
            } else {
                self.httpListener = check new (listenOn);
            }
        }

        // Configure the Pub/Sub client auth based on the provided config type
        http:ClientConfiguration pubSubClientConfig = {};
        if listenerConfig.auth is OAuth2Config {
            OAuth2Config oauthConfig = <OAuth2Config>listenerConfig.auth;
            http:OAuth2RefreshTokenGrantConfig oauthGrantConfig = {
                clientId: oauthConfig.clientId,
                clientSecret: oauthConfig.clientSecret,
                refreshUrl: oauthConfig.refreshUrl,
                refreshToken: oauthConfig.refreshToken
            };
            pubSubClientConfig = {
                auth: oauthGrantConfig,
                secureSocket: listenerConfig.secureSocketConfig
            };
        } else if listenerConfig.auth is http:BearerTokenConfig {
            // Pre-obtained access token — passed straight through.
            // Note: Google access tokens expire after ~1 hour. If the listener
            // runs longer than that, the delete-subscription call on
            // gracefulStop() may fail and the subscription will be orphaned
            // (same behaviour as a hard exit).
            pubSubClientConfig = {
                auth: <http:BearerTokenConfig>listenerConfig.auth,
                secureSocket: listenerConfig.secureSocketConfig
            };
        } else {
            // ServiceAccountConfig — use JWT Bearer Grant (RFC 7523) to exchange
            // a signed JWT assertion for an OAuth2 access token. Google Pub/Sub
            // requires a proper OAuth2 Bearer token, not a raw self-signed JWT.
            ServiceAccountConfig saConfig = <ServiceAccountConfig>listenerConfig.auth;

            jwt:IssuerConfig assertionConfig = {
                issuer: saConfig.issuer,
                username: saConfig.issuer,
                audience: GOOGLE_OAUTH2_TOKEN_URL,
                expTime: 3600,
                signatureConfig: saConfig.signatureConfig,
                customClaims: { "scope": PUBSUB_SCOPE }
            };
            string assertion = check jwt:issue(assertionConfig);

            http:OAuth2JwtBearerGrantConfig jwtBearerConfig = {
                tokenUrl: GOOGLE_OAUTH2_TOKEN_URL,
                assertion: assertion
            };
            pubSubClientConfig = {
                auth: jwtBearerConfig,
                secureSocket: listenerConfig.secureSocketConfig
            };
        }

        self.pubSubClient = check new (PUBSUB_BASE_URL, pubSubClientConfig);

        // Create an internal Google Chat API client using the same auth credentials.
        // This client is used by the Caller to make Chat API calls (reply, react, etc.).
        // The Client constructor handles scope configuration internally (uses chat.bot scope).
        self.chatClient = check new ({auth: listenerConfig.auth});

        self.dispatcherService = new DispatcherService("", self.chatClient);

    }

    # Attaches a `ChatService` implementation to this listener.
    #
    # Reads the `@ServiceConfig` annotation on the service to obtain the
    # `topicName` and `callbackURL`, then creates the Pub/Sub push subscription.
    #
    # + serviceRef - The service to attach (must have a `@ServiceConfig` annotation)
    # + attachPoint - The attach point (unused, kept for API compatibility)
    # + return - An error if the annotation is missing or subscription creation fails
    public function attach(GenericServiceType serviceRef, () attachPoint) returns @tainted error? {
        typedesc<any> serviceTypedesc = typeof serviceRef;
        ServiceConfiguration? svcConfig = serviceTypedesc.@ServiceConfig;
        if svcConfig is () {
            return error ListenerError("@chat:ServiceConfig annotation with topicName and callbackURL is required on the service");
        }
        check validateService(serviceRef);

        // Create a push subscription on the pre-existing topic
        SubscriptionDetail detail = check createPushSubscription(
            self.pubSubClient, svcConfig.topicName, svcConfig.callbackURL
        );
        self.subscriptionResource = detail.subscriptionResource;

        self.dispatcherService.setSubscriptionResource(self.subscriptionResource);

        string serviceTypeStr = self.getServiceTypeStr(serviceRef);
        check self.dispatcherService.addServiceRef(serviceTypeStr, serviceRef);
    }

    # Detaches a `ChatService` implementation from this listener.
    #
    # + serviceRef - The service to detach
    # + return - An error if detachment fails
    public isolated function detach(GenericServiceType serviceRef) returns error? {
        string serviceTypeStr = self.getServiceTypeStr(serviceRef);
        check self.dispatcherService.removeServiceRef(serviceTypeStr);
    }

    # Starts the HTTP listener to begin receiving Pub/Sub push events.
    #
    # + return - An error if starting fails
    public isolated function 'start() returns error? {
        if !self.dispatcherService.hasServiceRefs() {
            return error ListenerError("No ChatService has been attached to this listener");
        }
        check self.httpListener.attach(self.dispatcherService, ());
        return self.httpListener.'start();
    }

    # Gracefully stops the listener and deletes the Pub/Sub push subscription.
    #
    # + return - An error if cleanup or shutdown fails
    public isolated function gracefulStop() returns @tainted error? {
        error? subDeleteResult = deleteSubscription(self.pubSubClient, self.subscriptionResource);
        if subDeleteResult is error {
            log:printWarn("Failed to delete Pub/Sub subscription: " + subDeleteResult.message());
        }
        return self.httpListener.gracefulStop();
    }

    # Immediately stops the listener and deletes the Pub/Sub push subscription.
    #
    # + return - An error if cleanup or shutdown fails
    public isolated function immediateStop() returns error? {
        error? subDeleteResult = deleteSubscription(self.pubSubClient, self.subscriptionResource);
        if subDeleteResult is error {
            log:printWarn("Failed to delete Pub/Sub subscription: " + subDeleteResult.message());
        }
        return self.httpListener.immediateStop();
    }

    # Returns the service type string for the given service reference.
    #
    # + serviceRef - The service reference
    # + return - The service type identifier string
    private isolated function getServiceTypeStr(GenericServiceType serviceRef) returns string {
        return "ChatService";
    }
}

isolated function validateService(GenericServiceType serviceObj) returns error? = @java:Method {
    name: "validateService",
    'class: "io.ballerina.lib.googlechat.ChatEventDispatcher"
} external;
