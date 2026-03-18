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
import ballerina/log;

# Maximum time (in seconds) to wait for a handler to call respond() before
# returning an empty response to Google Chat. Google Chat has a 30s timeout
# for interaction events, so we use 28s to leave a small margin.
const int RESPONSE_TIMEOUT_SECONDS = 28;

# Internal HTTP service that receives Google Chat interaction events and
# dispatches them to the registered `ChatService` implementation.
#
# Google Chat sends a POST request with the raw Chat event JSON to the root
# resource (`/`). The `Authorization` header carries a Google-signed bearer
# token that is verified before the event is processed.
#
# The handler is dispatched on a virtual thread (fire-and-forget). A
# ResponseFuture bridges the handler's respond() call with the resource
# function's return value. The resource function blocks on the future until
# the handler calls respond() or a timeout expires, then returns the
# response payload directly (the HTTP framework sends it as the response body).
service class DispatcherService {
    *http:Service;
    private map<GenericServiceType> services = {};
    private final Client chatClient;
    private HttpConfig? httpConfig;

    isolated function init(Client chatClient, HttpConfig? httpConfig = ()) {
        self.chatClient = chatClient;
        self.httpConfig = httpConfig;
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
    // HTTP mode handler
    // ─────────────────────────────────────────────────────────────────────────

    # Handles direct HTTP POST requests from Google Chat.
    #
    # Verifies the bearer token, parses the event, dispatches to the handler
    # on a virtual thread, and waits for the handler to call respond().
    # Returns the response payload directly as `json` — the HTTP framework
    # sends it as the response body.
    #
    # If the handler does not call respond() within the timeout, an empty
    # JSON object `{}` is returned as a fallback.
    #
    # + request - The incoming HTTP request from Google Chat
    # + return - The JSON response payload, or an error
    resource function post .(http:Request request) returns json|error {
        HttpConfig? cfg = self.httpConfig;
        if cfg is () {
            log:printWarn("Received request but listener is not configured");
            return <json>{};
        }

        // Verify the bearer token before processing the event
        string|AuthenticationError bearerToken = extractBearerToken(request);
        if bearerToken is AuthenticationError {
            log:printWarn(WARN_HTTP_AUTH_FAILED, 'error = bearerToken);
            // Return 401 via error — the framework will handle it.
            // For now, return an empty body (Google Chat doesn't inspect status codes).
            return <json>{};
        }

        true|AuthenticationError verified = verifyChatBearerToken(bearerToken, cfg);
        if verified is AuthenticationError {
            log:printWarn(WARN_HTTP_AUTH_FAILED, 'error = verified);
            return <json>{};
        }

        // Parse the raw Chat event JSON directly
        json reqPayload = check request.getJsonPayload();
        log:printDebug(LOG_EVENT_DECODED + reqPayload.toJsonString());

        // Normalize the payload: APP_HOME events use a nested format where
        // event data is inside a `chat` sub-object (e.g., chat.type, chat.user,
        // chat.space) and `commonEventObject` is at root level. This is the
        // Google Workspace Add-ons event format, which Google Chat uses for
        // APP_HOME even for standard HTTP endpoint Chat apps.
        // We lift `chat.*` fields to root and map `commonEventObject` → `common`
        // so the payload matches the flat `ChatEvent` record structure.
        json normalizedPayload = reqPayload;
        json|error chatObj = reqPayload.chat;
        if chatObj is map<json> {
            map<json> payloadMap = check reqPayload.cloneWithType();
            // Lift all fields from `chat` (type, user, space, etc.) to root
            foreach var [key, value] in chatObj.entries() {
                payloadMap[key] = value;
            }
            // Map `commonEventObject` → `common` (the ChatEvent field name)
            json|error commonEventObj = reqPayload.commonEventObject;
            if commonEventObj is map<json> {
                payloadMap["common"] = commonEventObj;
            }
            // Remove the wrapper fields that don't exist in ChatEvent
            _ = payloadMap.removeIfHasKey("chat");
            _ = payloadMap.removeIfHasKey("commonEventObject");
            _ = payloadMap.removeIfHasKey("authorizationEventObject");
            normalizedPayload = payloadMap;
            log:printDebug("Normalized add-on style payload to flat ChatEvent format");
        }

        ChatEvent chatEvent = check normalizedPayload.cloneWithType(ChatEvent);
        log:printInfo(LOG_EVENT_RECEIVED + chatEvent.'type.toString());

        // Dispatch to the appropriate handler and wait for response
        return self.dispatch(chatEvent);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Dispatch logic
    // ─────────────────────────────────────────────────────────────────────────

    # Dispatches a Chat event to the appropriate remote function on the
    # registered ChatService. Creates a ResponseFuture, constructs the
    # event-specific Caller, fires the handler on a virtual thread, and
    # waits for the handler to call respond() (or until timeout).
    #
    # Returns the response payload set by respond(), or `{}` if no
    # response was provided (handler not found, timeout, etc.).
    #
    # + chatEvent - The parsed Chat interaction event
    # + return - The JSON response payload
    isolated function dispatch(ChatEvent chatEvent) returns json {
        GenericServiceType? genericService = self.services["ChatService"];
        if genericService is () {
            return <json>{};
        }

        string spaceId = "";
        string? spaceName = chatEvent.space?.name;
        if spaceName is string {
            string[] parts = re `/`.split(spaceName);
            if parts.length() >= 2 {
                spaceId = parts[1];
            }
        }

        match chatEvent.'type {
            MESSAGE => {
                return self.dispatchWithMessageCaller(chatEvent, "onMessage", spaceId, genericService);
            }
            ADDED_TO_SPACE => {
                return self.dispatchWithMessageCaller(chatEvent, "onAddedToSpace", spaceId, genericService);
            }
            REMOVED_FROM_SPACE => {
                // No caller needed — fire handler and return empty immediately.
                // The handler cannot send a response since the app is removed.
                nativeInvokeRemoteFunction(chatEvent, "onRemovedFromSpace", (), genericService);
                return <json>{};
            }
            CARD_CLICKED => {
                return self.dispatchWithCardClickedCaller(chatEvent, spaceId, genericService);
            }
            WIDGET_UPDATED => {
                return self.dispatchWithSimpleCaller(chatEvent, "onWidgetUpdated", genericService);
            }
            APP_COMMAND => {
                return self.dispatchWithMessageCaller(chatEvent, "onAppCommand", spaceId, genericService);
            }
            APP_HOME => {
                return self.dispatchWithSimpleCaller(chatEvent, "onAppHome", genericService);
            }
            SUBMIT_FORM => {
                return self.dispatchWithSimpleCaller(chatEvent, "onSubmitForm", genericService);
            }
            _ => {
                log:printWarn(WARN_UNKNOWN_EVENT_TYPE + chatEvent.'type.toString());
                return <json>{};
            }
        }
    }

    # Dispatches events that use `MessageCaller` (onMessage, onAddedToSpace, onAppCommand).
    # Creates a ResponseFuture and MessageCaller, fires the handler, waits for response.
    #
    # + chatEvent - The parsed Chat interaction event
    # + eventFunction - The remote function name to invoke on the service
    # + spaceId - The space ID extracted from the event, used by the Chat API client
    # + genericService - The registered ChatService instance
    # + return - The JSON response payload
    private isolated function dispatchWithMessageCaller(ChatEvent chatEvent,
            string eventFunction, string spaceId,
            GenericServiceType genericService) returns json {
        if !nativeHasRemoteFunction(genericService, eventFunction) {
            return <json>{};
        }
        handle responseFuture = createResponseFuture();
        MessageCaller caller = new (self.chatClient, spaceId, responseFuture);
        nativeInvokeRemoteFunction(chatEvent, eventFunction, caller, genericService);
        return self.awaitResponse(responseFuture);
    }

    # Dispatches an event with a CardClickedCaller.
    #
    # + chatEvent - The parsed Chat interaction event
    # + spaceId - The space ID extracted from the event, used by the Chat API client
    # + genericService - The registered ChatService instance
    # + return - The JSON response payload
    private isolated function dispatchWithCardClickedCaller(ChatEvent chatEvent,
            string spaceId, GenericServiceType genericService) returns json {
        if !nativeHasRemoteFunction(genericService, "onCardClicked") {
            return <json>{};
        }
        handle responseFuture = createResponseFuture();
        CardClickedCaller caller = new (self.chatClient, spaceId, responseFuture);
        nativeInvokeRemoteFunction(chatEvent, "onCardClicked", caller, genericService);
        return self.awaitResponse(responseFuture);
    }

    # Dispatches an event with a simple caller (AppHomeCaller, SubmitFormCaller, WidgetUpdatedCaller).
    #
    # + chatEvent - The parsed Chat interaction event
    # + eventFunction - The remote function name to invoke on the service
    # + genericService - The registered ChatService instance
    # + return - The JSON response payload
    private isolated function dispatchWithSimpleCaller(ChatEvent chatEvent,
            string eventFunction, GenericServiceType genericService) returns json {
        if !nativeHasRemoteFunction(genericService, eventFunction) {
            return <json>{};
        }
        handle responseFuture = createResponseFuture();
        object {} caller;
        if eventFunction == "onWidgetUpdated" {
            caller = new WidgetUpdatedCaller(responseFuture);
        } else if eventFunction == "onAppHome" {
            caller = new AppHomeCaller(responseFuture);
        } else {
            caller = new SubmitFormCaller(responseFuture);
        }
        nativeInvokeRemoteFunction(chatEvent, eventFunction, caller, genericService);
        return self.awaitResponse(responseFuture);
    }

    # Waits for the handler to call respond() via the ResponseFuture, or
    # returns `{}` if the timeout expires.
    #
    # + responseFuture - The handle to the ResponseFuture to wait on
    # + return - The JSON payload from respond(), or `{}` on timeout
    private isolated function awaitResponse(handle responseFuture) returns json {
        json result = waitForResponse(responseFuture, RESPONSE_TIMEOUT_SECONDS);
        // If null (timeout or handler didn't call respond), return empty JSON.
        // The null from Java maps to () in Ballerina, which is a valid json value
        // but we want to return {} to Google Chat instead.
        if result == () {
            return <json>{};
        }
        return result;
    }
}

# Native external function that dispatches a Chat event to the appropriate
# remote function on the ChatService. The Java implementation inspects the
# function signature, injects the ChatEvent and the pre-built Caller into
# the args, and executes the function on a virtual thread (fire-and-forget).
#
# + chatEvent - The parsed Chat interaction event to pass to the handler
# + eventFunction - The name of the remote function to invoke
# + callerObj - The event-specific Caller object to inject, or `()` for no caller
# + serviceObj - The registered ChatService instance
isolated function nativeInvokeRemoteFunction(ChatEvent chatEvent, string eventFunction,
        object {}? callerObj, GenericServiceType serviceObj) = @java:Method {
    name: "invokeRemoteFunction",
    'class: "io.ballerina.lib.googleapis.chat.ChatEventDispatcher"
} external;

# Native helper that checks whether a remote function exists on the service.
#
# + serviceObj - The registered ChatService instance
# + eventFunction - The name of the remote function to check for
# + return - `true` if the function exists on the service, `false` otherwise
isolated function nativeHasRemoteFunction(GenericServiceType serviceObj,
        string eventFunction) returns boolean = @java:Method {
    name: "hasRemoteFunction",
    'class: "io.ballerina.lib.googleapis.chat.ChatEventDispatcher"
} external;
