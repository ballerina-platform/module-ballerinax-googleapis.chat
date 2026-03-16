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
# either Google Cloud Pub/Sub push subscriptions or direct HTTP delivery.
#
# ## Delivery modes
#
# The mode is determined by the `@ServiceConfig` annotation on the attached
# `ChatService`:
#
# - **Pub/Sub mode** (`PubSubConfig`): The listener auto-creates a push
# subscription on the configured topic. Pub/Sub pushes events as HTTP POST
# requests to the `callbackURL` path `/webhook`. On shutdown, the
# subscription is deleted automatically.
#
# - **HTTP mode** (`HttpConfig`): Google Chat sends interaction events directly
# to the listener's root path (`/`). Each request carries a bearer token in
# the `Authorization` header that is verified before processing. No external
# resources are created or cleaned up.
#
# ## Usage — Pub/Sub mode
#
# ```ballerina
# listener chat:Listener chatListener = new (8000, {
#     auth: {
#         path: "/path/to/service-account.json"
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
# }
# ```
#
# ## Usage — HTTP mode
#
# ```ballerina
# listener chat:Listener chatListener = new (8090, {
#     auth: {
#         path: "/path/to/service-account.json"
#     }
# });
#
# @chat:ServiceConfig {
#     endpointUrl: "https://my-app.example.com"
# }
# service chat:ChatService on chatListener {
#     remote function onMessage(chat:ChatEvent event, chat:Caller caller) returns error? {
#         _ = check caller->reply("Hello!");
#     }
# }
# ```
@display {label: "Google Chat", iconPath: "docs/icon.png"}
public class Listener {
    private http:Listener httpListener;
    private DispatcherService dispatcherService;
    private final Client chatClient;

    # Pub/Sub HTTP client, used for subscription management in Pub/Sub mode.
    # Declared `final` because it is assigned once in `init` and never changed,
    # allowing isolated methods to read it without a lock. Created for all modes
    # so the field always has a value; in HTTP mode it is present but unused.
    private final http:Client pubSubClient;

    # Set during attach once the Pub/Sub subscription is created.
    # Guarded by a lock in isolated methods because it is mutated after init.
    private string subscriptionResource = "";

    # Initializes the Google Chat trigger listener.
    #
    # Sets up the HTTP listener and (if needed) the Pub/Sub client. The
    # delivery mode is determined later in `attach()` from the `@ServiceConfig`
    # annotation on the service. No external resources are created here.
    #
    # + listenOn - The port or HTTP listener to listen on. Defaults to port 8000.
    # + listenerConfig - Configuration including auth credentials
    # + return - An error if initialization fails
    public function init(int|http:Listener listenOn = 8000, *ListenerConfig listenerConfig) returns error? {
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

        // Create the Chat API client — used by the Caller in both modes.
        self.chatClient = check new ({auth: listenerConfig.auth});

        // Build the Pub/Sub HTTP client. Assigned final here; it is always
        // created regardless of mode so the field has a stable value from init.
        // In HTTP mode it is present but never used for subscription management.
        // normalizeServiceAccountAuth() does file I/O so it must run here in
        // the non-isolated init(), not in the isolated stop methods.
        self.pubSubClient = check createPubSubClient(listenerConfig);

        self.dispatcherService = new DispatcherService("", self.chatClient);
    }

    # Attaches a `ChatService` implementation to this listener.
    #
    # Reads the `@ServiceConfig` annotation on the service to determine the
    # delivery mode:
    #
    # - **`PubSubConfig`**: Creates a Pub/Sub push subscription on the
    # pre-existing topic and stores the subscription resource name for
    # cleanup on shutdown.
    # - **`HttpConfig`**: Configures the dispatcher with token verification
    # settings. No external resources are created.
    #
    # + serviceRef - The service to attach (must have a `@ServiceConfig` annotation)
    # + attachPoint - The attach point (unused, kept for API compatibility)
    # + return - An error if the annotation is missing or subscription creation fails
    public function attach(GenericServiceType serviceRef, () attachPoint) returns @tainted error? {
        typedesc<any> serviceTypedesc = typeof serviceRef;
        ServiceConfiguration? svcConfig = serviceTypedesc.@ServiceConfig;
        if svcConfig is () {
            return error ListenerError("@chat:ServiceConfig annotation is required on the service. " +
                "Provide a PubSubConfig (topicName + callbackURL) for Pub/Sub mode, " +
                "an HttpEndpointUrlConfig (endpointUrl) or ProjectNumberConfig (projectNumber) for HTTP mode.");
        }
        check validateService(serviceRef);

        if svcConfig is PubSubConfig {
            // ── Pub/Sub mode ─────────────────────────────────────────────────
            SubscriptionDetail detail = check createPushSubscription(
                    self.pubSubClient, svcConfig.topicName, svcConfig.callbackURL
            );
            self.subscriptionResource = detail.subscriptionResource;
            self.dispatcherService.setSubscriptionResource(self.subscriptionResource);
            log:printInfo("Google Chat listener started in Pub/Sub mode");
        } else {
            // ── HTTP mode ─────────────────────────────────────────────────────
            self.dispatcherService.setHttpConfig(<HttpConfig>svcConfig);
            log:printInfo("Google Chat listener started in HTTP mode");
        }

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

    # Starts the HTTP listener to begin receiving events.
    #
    # + return - An error if starting fails
    public isolated function 'start() returns error? {
        if !self.dispatcherService.hasServiceRefs() {
            return error ListenerError("No ChatService has been attached to this listener");
        }
        check self.httpListener.attach(self.dispatcherService, ());
        return self.httpListener.'start();
    }

    # Gracefully stops the listener.
    #
    # In Pub/Sub mode, deletes the push subscription before shutting down.
    # In HTTP mode, simply stops the HTTP listener.
    #
    # + return - An error if cleanup or shutdown fails
    public isolated function gracefulStop() returns @tainted error? {
        string subResource;
        lock {
            subResource = self.subscriptionResource;
        }
        if subResource != "" {
            error? subDeleteResult = deleteSubscription(self.pubSubClient, subResource);
            if subDeleteResult is error {
                log:printWarn("Failed to delete Pub/Sub subscription: " + subDeleteResult.message());
            }
        }
        return self.httpListener.gracefulStop();
    }

    # Immediately stops the listener.
    #
    # In Pub/Sub mode, attempts to delete the push subscription before stopping.
    # In HTTP mode, simply stops the HTTP listener.
    #
    # + return - An error if cleanup or shutdown fails
    public isolated function immediateStop() returns error? {
        string subResource;
        lock {
            subResource = self.subscriptionResource;
        }
        if subResource != "" {
            error? subDeleteResult = deleteSubscription(self.pubSubClient, subResource);
            if subDeleteResult is error {
                log:printWarn("Failed to delete Pub/Sub subscription: " + subDeleteResult.message());
            }
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
    'class: "io.ballerina.lib.googleapis.chat.ChatEventDispatcher"
} external;

# Creates the Pub/Sub HTTP client from the listener configuration.
#
# Extracted from `Listener.init()` so that `pubSubClient` can be assigned
# in a single expression, allowing it to be declared `final`.
#
# The client is created for all modes (both Pub/Sub and HTTP) so the field
# always has a stable value. In HTTP mode the client is present but unused.
#
# + listenerConfig - The listener configuration with auth credentials
# + return - A configured `http:Client` for the Pub/Sub API, or an error
function createPubSubClient(ListenerConfig listenerConfig) returns http:Client|error {
    if listenerConfig.auth is OAuth2Config {
        OAuth2Config oauthConfig = <OAuth2Config>listenerConfig.auth;
        return new (PUBSUB_BASE_URL, {
            auth: <http:OAuth2RefreshTokenGrantConfig>{
                clientId: oauthConfig.clientId,
                clientSecret: oauthConfig.clientSecret,
                refreshUrl: oauthConfig.refreshUrl,
                refreshToken: oauthConfig.refreshToken
            },
            secureSocket: listenerConfig.secureSocketConfig
        });
    }

    if listenerConfig.auth is http:BearerTokenConfig {
        // Pre-obtained access token — passed straight through.
        // Note: Google access tokens expire after ~1 hour. If the listener
        // runs longer, the delete-subscription call on gracefulStop() may
        // fail and the subscription will be orphaned.
        return new (PUBSUB_BASE_URL, {
            auth: <http:BearerTokenConfig>listenerConfig.auth,
            secureSocket: listenerConfig.secureSocketConfig
        });
    }

    // Service account auth — use JWT Bearer Grant (RFC 7523) to exchange
    // a signed JWT assertion for an OAuth2 access token.
    NormalizedServiceAccount saConfig = check normalizeServiceAccountAuth(
            <ServiceAccountAuthConfig>listenerConfig.auth);

    jwt:IssuerConfig assertionConfig = {
        issuer: saConfig.issuer,
        username: saConfig.issuer,
        audience: GOOGLE_OAUTH2_TOKEN_URL,
        expTime: 3600,
        signatureConfig: saConfig.signatureConfig,
        customClaims: {"scope": PUBSUB_SCOPE}
    };
    string assertion = check jwt:issue(assertionConfig);

    return new (PUBSUB_BASE_URL, {
        auth: <http:OAuth2JwtBearerGrantConfig>{
            tokenUrl: GOOGLE_OAUTH2_TOKEN_URL,
            assertion: assertion
        },
        secureSocket: listenerConfig.secureSocketConfig
    });
}
