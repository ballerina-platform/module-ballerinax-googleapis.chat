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
import ballerina/lang.'array;
import ballerina/log;

# Internal HTTP service that receives Google Chat interaction events and
# dispatches them to the registered `ChatService` implementation.
#
# Two delivery modes are supported, selected when the listener attaches a
# service via `@ServiceConfig`:
#
# **Pub/Sub mode** (`PubSubConfig`):
# Pub/Sub pushes a JSON envelope to the `/webhook` resource. The event payload
# is base64-encoded inside the `message.data` field of the envelope. No
# secondary API call is needed — the full Chat event is embedded in the push.
# The incoming subscription name is validated against the one created at startup.
#
# **HTTP mode** (`HttpEndpointUrlConfig` or `ProjectNumberConfig`):
# Google Chat sends a POST request with the raw Chat event JSON to the root
# resource (`/`). The `Authorization` header carries a Google-signed bearer
# token that is verified before the event is processed. Requests that fail
# verification are rejected with HTTP 401.
service class DispatcherService {
    *http:Service;
    private map<GenericServiceType> services = {};
    private string subscriptionResource;
    private final Client chatClient;
    # Set to the `HttpConfig` when operating in HTTP mode; `()` in Pub/Sub mode.
    private HttpConfig? httpConfig;


    isolated function init(string subscriptionResource, Client chatClient,
            HttpConfig? httpConfig = ()) {
        self.subscriptionResource = subscriptionResource;
        self.chatClient = chatClient;
        self.httpConfig = httpConfig;
    }

    isolated function setSubscriptionResource(string subscriptionResource) {
        self.subscriptionResource = subscriptionResource;
    }

    isolated function setHttpConfig(HttpConfig httpConfig) {
        self.httpConfig = httpConfig;
    }

    isolated function addServiceRef(string serviceType, GenericServiceType genericService) returns error? {
        if self.services.hasKey(serviceType) {
            return error ListenerError(ERR_SERVICE_ATTACH);
        }
        self.services[serviceType] = genericService;
    }

    isolated function removeServiceRef(string serviceType) returns error? {
        if !self.services.hasKey(serviceType) {
            return error ListenerError(ERR_SERVICE_DETACH);
        }
        _ = self.services.remove(serviceType);
    }

    isolated function hasServiceRefs() returns boolean {
        return self.services.length() > 0;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Pub/Sub mode handler
    // ─────────────────────────────────────────────────────────────────────────

    # Handles incoming Pub/Sub push notifications.
    #
    # The Pub/Sub message envelope has the structure:
    # ```json
    # {
    #   "message": {
    #     "data": "<base64-encoded Chat event JSON>",
    #     "messageId": "...",
    #     "publishTime": "..."
    #   },
    #   "subscription": "projects/{project}/subscriptions/{sub}"
    # }
    # ```
    #
    # + httpCaller - The HTTP caller to respond to
    # + request - The incoming HTTP request containing the Pub/Sub push message
    # + return - An error if processing fails
    resource isolated function post webhook(http:Caller httpCaller, http:Request request) returns error? {
        json reqPayload = check request.getJsonPayload();

        // Validate the push is from the subscription this listener created
        string incomingSubscription = check reqPayload.subscription;
        if self.subscriptionResource != incomingSubscription {
            log:printWarn(WARN_UNKNOWN_SUBSCRIPTION + incomingSubscription);
            check httpCaller->respond(http:STATUS_OK);
            return;
        }

        // Decode the base64-encoded event data from the Pub/Sub message
        string base64Data = check reqPayload.message.data;
        byte[] decodedBytes = check 'array:fromBase64(base64Data);
        string eventJson = check string:fromBytes(decodedBytes);
        json eventPayload = check eventJson.fromJsonString();
        log:printDebug(LOG_EVENT_DECODED + eventJson);

        // Parse the event into a ChatEvent record
        ChatEvent chatEvent = check eventPayload.cloneWithType(ChatEvent);
        log:printInfo(LOG_EVENT_RECEIVED + chatEvent.'type.toString());

        // Dispatch to the appropriate handler. The native dispatcher schedules
        // the service invocation asynchronously on a virtual thread.
        check self.dispatch(chatEvent);

        // Acknowledge the Pub/Sub message
        check httpCaller->respond(http:STATUS_OK);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HTTP mode handler
    // ─────────────────────────────────────────────────────────────────────────

    # Handles direct HTTP POST requests from Google Chat (HTTP mode).
    #
    # Google Chat sends the raw Chat event JSON as the request body. Before
    # processing, the bearer token in the `Authorization` header is verified to
    # confirm the request originates from Google Chat. Requests that fail
    # verification are rejected with HTTP 401 Unauthorized.
    #
    # + httpCaller - The HTTP caller to respond to
    # + request - The incoming HTTP request from Google Chat
    # + return - An error if processing fails
    resource isolated function post .(http:Caller httpCaller, http:Request request) returns error? {
        HttpConfig? cfg = self.httpConfig;
        if cfg is () {
            // HTTP mode resource invoked but not configured — reject silently
            log:printWarn("Received request on HTTP endpoint but listener is not in HTTP mode");
            check httpCaller->respond(http:STATUS_NOT_FOUND);
            return;
        }

        // Verify the bearer token before processing the event
        string|AuthenticationError bearerToken = extractBearerToken(request);
        if bearerToken is AuthenticationError {
            log:printWarn(WARN_HTTP_AUTH_FAILED, 'error = bearerToken);
            check httpCaller->respond(http:STATUS_UNAUTHORIZED);
            return;
        }

        true|AuthenticationError verified = verifyChatBearerToken(bearerToken, cfg);
        if verified is AuthenticationError {
            log:printWarn(WARN_HTTP_AUTH_FAILED, 'error = verified);
            check httpCaller->respond(http:STATUS_UNAUTHORIZED);
            return;
        }

        // Parse the raw Chat event JSON directly (no Pub/Sub envelope)
        json reqPayload = check request.getJsonPayload();
        log:printDebug(LOG_EVENT_DECODED + reqPayload.toJsonString());

        ChatEvent chatEvent = check reqPayload.cloneWithType(ChatEvent);
        log:printInfo(LOG_EVENT_RECEIVED + chatEvent.'type.toString());

        // Dispatch to the appropriate handler
        check self.dispatch(chatEvent);

        json emptyResponse = {};
        check httpCaller->respond(emptyResponse);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Shared dispatch logic
    // ─────────────────────────────────────────────────────────────────────────

    # Dispatches a Chat event to the appropriate remote function on the
    # registered ChatService based on the event type.
    #
    # + chatEvent - The parsed Chat interaction event
    # + return - An error if dispatch scheduling fails
    isolated function dispatch(ChatEvent chatEvent) returns error? {
        GenericServiceType? chatService = self.services["ChatService"];
        if chatService is () {
            return;
        }

        match chatEvent.'type {
            MESSAGE => {
                check self.executeRemoteFunc(chatEvent, "onMessage");
            }
            ADDED_TO_SPACE => {
                check self.executeRemoteFunc(chatEvent, "onAddedToSpace");
            }
            REMOVED_FROM_SPACE => {
                check self.executeRemoteFunc(chatEvent, "onRemovedFromSpace");
            }
            CARD_CLICKED => {
                check self.executeRemoteFunc(chatEvent, "onCardClicked");
            }
            WIDGET_UPDATED => {
                check self.executeRemoteFunc(chatEvent, "onWidgetUpdated");
            }
            APP_COMMAND => {
                check self.executeRemoteFunc(chatEvent, "onAppCommand");
            }
            APP_HOME => {
                check self.executeRemoteFunc(chatEvent, "onAppHome");
            }
            SUBMIT_FORM => {
                check self.executeRemoteFunc(chatEvent, "onSubmitForm");
            }
            _ => {
                log:printWarn(WARN_UNKNOWN_EVENT_TYPE + chatEvent.'type.toString());
            }
        }
    }

    # Executes a remote function on the registered ChatService using the native
    # Java dispatcher. The dispatcher inspects the remote function signature and
    # injects both the ChatEvent and (optionally) a Caller if the function
    # signature includes one.
    #
    # + chatEvent - The event data to pass to the remote function
    # + eventFunction - The name of the remote function to invoke (e.g., "onMessage")
    # + return - An error if invocation scheduling fails
    private isolated function executeRemoteFunc(ChatEvent chatEvent,
            string eventFunction) returns error? {
        GenericServiceType? genericService = self.services["ChatService"];
        if genericService is GenericServiceType {
            string spaceId = "";
            if check requiresCaller(genericService, eventFunction) {
                spaceId = check extractSpaceId(chatEvent);
            }
            check nativeInvokeRemoteFunction(chatEvent, self.chatClient,
                    spaceId, eventFunction, genericService);
        }
    }
}

# Extracts the `{spaceId}` segment from a Chat space resource name.
# The space name format is `spaces/{spaceId}`.
#
# + chatEvent - The chat event
# + return - The space ID, or an error if not found
isolated function extractSpaceId(ChatEvent chatEvent) returns string|error {
    string? spaceName = chatEvent.space?.name;
    if spaceName is () {
        return error DispatchError("Cannot create a Caller for this event: space name is not available");
    }
    string[] parts = re `/`.split(spaceName);
    if parts.length() >= 2 {
        return parts[1];
    }
    return error DispatchError("Cannot create a Caller for this event: invalid space name '" + spaceName + "'");
}

# Native external function that dispatches a Chat event to the appropriate
# remote function on the ChatService. The Java implementation inspects the
# function signature and injects a Caller object if the function expects one.
#
# + chatEvent - The event data
# + chatClient - The internal Chat API client for the Caller
# + spaceId - The space ID from the event
# + eventFunction - The name of the remote function to invoke
# + serviceObj - The user's ChatService object
# + return - An error if invocation scheduling fails
isolated function nativeInvokeRemoteFunction(ChatEvent chatEvent, Client chatClient,
        string spaceId, string eventFunction, GenericServiceType serviceObj) returns error? = @java:Method {
    name: "invokeRemoteFunction",
    'class: "io.ballerina.lib.googleapis.chat.ChatEventDispatcher"
} external;

isolated function requiresCaller(GenericServiceType serviceObj, string eventFunction) returns boolean|error = @java:Method {
    name: "requiresCaller",
    'class: "io.ballerina.lib.googleapis.chat.ChatEventDispatcher"
} external;
