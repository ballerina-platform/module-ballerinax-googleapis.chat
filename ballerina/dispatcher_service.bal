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

# Internal HTTP service that receives Pub/Sub push notifications and dispatches
# them to the registered `ChatService` implementation.
#
# Unlike the Gmail trigger (which only receives a historyId and must fetch full
# data from the Gmail API), the Google Chat Pub/Sub push delivers the **complete
# interaction event payload** in the message data. This means no secondary API
# calls are needed to get the event details.
service class DispatcherService {
    *http:Service;
    private map<GenericServiceType> services = {};
    private string subscriptionResource;
    private final Client chatClient;

    isolated function init(string subscriptionResource, Client chatClient) {
        self.subscriptionResource = subscriptionResource;
        self.chatClient = chatClient;
    }

    isolated function setSubscriptionResource(string subscriptionResource) {
        self.subscriptionResource = subscriptionResource;
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
    'class: "io.ballerina.lib.googlechat.ChatEventDispatcher"
} external;

isolated function requiresCaller(GenericServiceType serviceObj, string eventFunction) returns boolean|error = @java:Method {
    name: "requiresCaller",
    'class: "io.ballerina.lib.googlechat.ChatEventDispatcher"
} external;
