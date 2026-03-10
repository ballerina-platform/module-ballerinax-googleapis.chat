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
import ballerina/lang.'array;
import ballerina/log;
import ballerinax/asyncapi.native.handler;

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
    private handler:NativeHandler nativeHandler = new ();
    private final string subscriptionResource;

    isolated function init(string subscriptionResource) {
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
    # + caller - The HTTP caller to respond to
    # + request - The incoming HTTP request containing the Pub/Sub push message
    # + return - An error if processing fails
    resource isolated function post webhook(http:Caller caller, http:Request request) returns error? {
        json reqPayload = check request.getJsonPayload();

        // Validate the push is from the subscription this listener created
        string incomingSubscription = check reqPayload.subscription;
        if self.subscriptionResource != incomingSubscription {
            log:printWarn(WARN_UNKNOWN_SUBSCRIPTION + incomingSubscription);
            check caller->respond(http:STATUS_OK);
            return;
        }

        // Decode the base64-encoded event data from the Pub/Sub message
        string base64Data = check reqPayload.message.data;
        byte[] decodedBytes = check 'array:fromBase64(base64Data);
        string eventJson = check string:fromBytes(decodedBytes);
        json eventPayload = check eventJson.fromJsonString();

        // Parse the event into a ChatEvent record
        ChatEvent chatEvent = check eventPayload.cloneWithType(ChatEvent);
        log:printInfo(LOG_EVENT_RECEIVED + chatEvent.'type.toString());

        // Dispatch to the appropriate handler
        check self.dispatch(chatEvent);

        // Acknowledge the Pub/Sub message
        check caller->respond(http:STATUS_OK);
    }

    # Dispatches a Chat event to the appropriate remote function on the
    # registered ChatService based on the event type.
    #
    # + chatEvent - The parsed Chat interaction event
    # + return - An error if dispatching fails
    isolated function dispatch(ChatEvent chatEvent) returns error? {
        GenericServiceType? chatService = self.services["ChatService"];
        if chatService is () {
            return;
        }

        match chatEvent.'type {
            MESSAGE => {
                check self.executeRemoteFunc(chatEvent, "message", "onMessage");
            }
            ADDED_TO_SPACE => {
                check self.executeRemoteFunc(chatEvent, "addedToSpace", "onAddedToSpace");
            }
            REMOVED_FROM_SPACE => {
                check self.executeRemoteFunc(chatEvent, "removedFromSpace", "onRemovedFromSpace");
            }
            CARD_CLICKED => {
                check self.executeRemoteFunc(chatEvent, "cardClicked", "onCardClicked");
            }
            APP_HOME => {
                check self.executeRemoteFunc(chatEvent, "appHome", "onAppHome");
            }
            SUBMIT_FORM => {
                check self.executeRemoteFunc(chatEvent, "submitForm", "onSubmitForm");
            }
            _ => {
                log:printWarn(WARN_UNKNOWN_EVENT_TYPE + chatEvent.'type.toString());
            }
        }
    }

    # Executes a remote function on the registered ChatService using the native handler.
    #
    # + chatEvent - The event data to pass to the remote function
    # + eventName - A logical name for the event (used by the native handler)
    # + eventFunction - The name of the remote function to invoke (e.g., "onMessage")
    # + return - An error if invocation fails
    private isolated function executeRemoteFunc(ChatEvent chatEvent, string eventName,
            string eventFunction) returns error? {
        GenericServiceType? genericService = self.services["ChatService"];
        if genericService is GenericServiceType {
            check self.nativeHandler.invokeRemoteFunction(chatEvent, eventName, eventFunction, genericService);
        }
    }
}
