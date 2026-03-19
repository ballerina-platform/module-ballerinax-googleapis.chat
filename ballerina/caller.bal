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

import ballerina/jballerina.java;

// ═══════════════════════════════════════════════════════════════════════════════
// MessageCaller — for onMessage, onAddedToSpace, onAppCommand
// ═══════════════════════════════════════════════════════════════════════════════

# Caller for message-related events (`onMessage`, `onAddedToSpace`, `onAppCommand`).
#
# The `respond` method sets the synchronous HTTP response that will be sent
# back to Google Chat. The response is delivered immediately, and the handler
# continues executing — allowing long-running operations (e.g., AI agent tool
# calls) to use async Chat API methods like `sendMessage`.
#
# Async Chat API operations (`sendMessage`, `updateMessage`, `deleteMessage`,
# `getSpace`) are available for follow-up actions after calling `respond`.
#
# **Example — quick reply:**
# ```ballerina
# remote function onMessage(chat:MessageEvent event, chat:MessageCaller caller) returns error? {
#     check caller->respond({ text: "Got your message!" });
# }
# ```
#
# **Example — AI agent (respond immediately, then process):**
# ```ballerina
# remote function onMessage(chat:MessageEvent event, chat:MessageCaller caller) returns error? {
#     check caller->respond({});  // acknowledge immediately
#     string agentResponse = check runAgent(event.message.text ?: "");
#     _ = check caller->sendMessage({ text: agentResponse });
# }
# ```
@display {label: "Google Chat Message Caller"}
public isolated client class MessageCaller {
    private final Client chatClient;
    private final string spaceId;
    private final handle responseFuture;
    private boolean responded = false;

    # Initializes the MessageCaller. Called internally by the dispatcher.
    isolated function init(Client chatClient, string spaceId, handle responseFuture) {
        self.chatClient = chatClient;
        self.spaceId = spaceId;
        self.responseFuture = responseFuture;
    }

    # Sets the synchronous response to send back to Google Chat.
    #
    # This can only be called once per event. The response is delivered
    # immediately as the HTTP response body. The handler continues executing
    # after this returns.
    #
    # The `Message` record can include `text`, `cardsV2`, `actionResponse`
    # (for dialogs, card updates, link previews), and `accessoryWidgets`.
    #
    # + response - The message to send as the synchronous response
    # + return - An error if respond has already been called
    remote isolated function respond(Message response) returns error? {
        lock {
            if self.responded {
                return error DispatchError("respond() has already been called for this event");
            }
            self.responded = true;
        }
        json payload = response.toJson();
        completeFuture(self.responseFuture, payload);
    }

    # Sends a message to the space asynchronously via the Chat API.
    #
    # + message - The message payload to send
    # + return - The created message or an error
    remote isolated function sendMessage(CreateMessageRequest message) returns Message|error {
        return self.chatClient->/spaces/[self.spaceId]/messages.post(message);
    }

    # Updates a bot-accessible message in the same space.
    #
    # + message - The message to update (must have `name` set)
    # + queries - Query parameters such as `updateMask` and `allowMissing`
    # + return - The updated message or an error
    remote isolated function updateMessage(Message message, *UpdateMessageQueries queries) returns Message|error {
        string resolvedMessageId = check resolveMessageId(message.name);
        UpdateMessageRequest request = {
            text: message.text,
            cardsV2: message.cardsV2,
            fallbackText: message.fallbackText,
            accessoryWidgets: message.accessoryWidgets
        };
        if queries.allowMissing is boolean {
            return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].patch(
                request,
                updateMask = queries.updateMask,
                allowMissing = <boolean>queries.allowMissing
            );
        }
        return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].patch(
            request,
            updateMask = queries.updateMask
        );
    }

    # Deletes a bot-accessible message in the same space.
    #
    # + message - The message to delete (must have `name` set)
    # + return - An error if the operation fails
    remote isolated function deleteMessage(Message message) returns error? {
        string resolvedMessageId = check resolveMessageId(message.name);
        return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].delete();
    }

    # Returns details about the space where the event occurred.
    #
    # + return - The space details or an error
    remote isolated function getSpace() returns Space|error {
        return self.chatClient->/spaces/[self.spaceId];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AppHomeCaller — for onAppHome
// ═══════════════════════════════════════════════════════════════════════════════

# Caller for app home events (`onAppHome`).
#
# The `respond` method sets the card to display in the app home tab. The caller
# automatically wraps the `Card` in the required `RenderActions` / `pushCard`
# structure.
#
# **Example:**
# ```ballerina
# remote function onAppHome(chat:ChatEvent event, chat:AppHomeCaller caller) returns error? {
#     check caller->respond({
#         sections: [{
#             widgets: [{ textParagraph: { text: "Welcome to the app home!" } }]
#         }]
#     });
# }
# ```
@display {label: "Google Chat App Home Caller"}
public isolated client class AppHomeCaller {
    private final handle responseFuture;
    private boolean responded = false;

    # Initializes the AppHomeCaller. Called internally by the dispatcher.
    isolated function init(handle responseFuture) {
        self.responseFuture = responseFuture;
    }

    # Sets the synchronous response with the app home card.
    #
    # The `Card` is automatically wrapped in the required response structure:
    # `{ action: { navigations: [{ pushCard: <card> }] } }`
    #
    # + card - The card to display in the app home tab
    # + return - An error if respond has already been called
    remote isolated function respond(Card card) returns error? {
        lock {
            if self.responded {
                return error DispatchError("respond() has already been called for this event");
            }
            self.responded = true;
        }
        AppHomeResponse appHomeResponse = {
            action: {
                navigations: [{pushCard: card}]
            }
        };
        json payload = appHomeResponse.toJson();
        completeFuture(self.responseFuture, payload);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CardClickedCaller — for onCardClicked
// ═══════════════════════════════════════════════════════════════════════════════

# Caller for card-clicked events (`onCardClicked`).
#
# The `respond` method accepts either a `Message` (for regular card interactions
# including dialogs, card updates, and link preview updates) or a `Card` (for
# card interactions originating from the app home, auto-wrapped in RenderActions).
#
# **Example — update a card:**
# ```ballerina
# remote function onCardClicked(chat:ChatEvent event, chat:CardClickedCaller caller) returns error? {
#     check caller->respond({
#         actionResponse: { 'type: chat:UPDATE_MESSAGE },
#         cardsV2: [{ cardId: "updated", card: { ... } }]
#     });
# }
# ```
#
# **Example — open a dialog:**
# ```ballerina
# remote function onCardClicked(chat:ChatEvent event, chat:CardClickedCaller caller) returns error? {
#     check caller->respond({
#         actionResponse: {
#             'type: chat:DIALOG,
#             dialogAction: { dialog: { body: myDialogCard } }
#         }
#     });
# }
# ```
@display {label: "Google Chat Card Clicked Caller"}
public isolated client class CardClickedCaller {
    private final Client chatClient;
    private final string spaceId;
    private final handle responseFuture;
    private boolean responded = false;

    # Initializes the CardClickedCaller. Called internally by the dispatcher.
    isolated function init(Client chatClient, string spaceId, handle responseFuture) {
        self.chatClient = chatClient;
        self.spaceId = spaceId;
        self.responseFuture = responseFuture;
    }

    # Sets the synchronous response back to Google Chat.
    #
    # Accepts a `Message` for regular card interactions (dialogs, card updates,
    # link preview updates), or a `Card` for interactions originating from the
    # app home (auto-wrapped in RenderActions with `updateCard` navigation).
    #
    # + response - The response to send
    # + return - An error if respond has already been called
    remote isolated function respond(Message|Card response) returns error? {
        lock {
            if self.responded {
                return error DispatchError("respond() has already been called for this event");
            }
            self.responded = true;
        }
        json payload;
        if response is Message {
            payload = response.toJson();
        } else {
            Card card = <Card>response;
            RenderActionsResponse renderResponse = {
                renderActions: {
                    action: {
                        navigations: [{updateCard: card}]
                    }
                }
            };
            payload = renderResponse.toJson();
        }
        completeFuture(self.responseFuture, payload);
    }

    # Sends a message to the space asynchronously via the Chat API.
    #
    # + message - The message payload to send
    # + return - The created message or an error
    remote isolated function sendMessage(CreateMessageRequest message) returns Message|error {
        return self.chatClient->/spaces/[self.spaceId]/messages.post(message);
    }

    # Updates a bot-accessible message in the same space.
    #
    # + message - The message to update (must have `name` set)
    # + queries - Query parameters such as `updateMask` and `allowMissing`
    # + return - The updated message or an error
    remote isolated function updateMessage(Message message, *UpdateMessageQueries queries) returns Message|error {
        string resolvedMessageId = check resolveMessageId(message.name);
        UpdateMessageRequest request = {
            text: message.text,
            cardsV2: message.cardsV2,
            fallbackText: message.fallbackText,
            accessoryWidgets: message.accessoryWidgets
        };
        if queries.allowMissing is boolean {
            return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].patch(
                request,
                updateMask = queries.updateMask,
                allowMissing = <boolean>queries.allowMissing
            );
        }
        return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].patch(
            request,
            updateMask = queries.updateMask
        );
    }

    # Deletes a bot-accessible message in the same space.
    #
    # + message - The message to delete (must have `name` set)
    # + return - An error if the operation fails
    remote isolated function deleteMessage(Message message) returns error? {
        string resolvedMessageId = check resolveMessageId(message.name);
        return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].delete();
    }

    # Returns details about the space where the event occurred.
    #
    # + return - The space details or an error
    remote isolated function getSpace() returns Space|error {
        return self.chatClient->/spaces/[self.spaceId];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SubmitFormCaller — for onSubmitForm (from app home)
// ═══════════════════════════════════════════════════════════════════════════════

# Caller for submit-form events from app home (`onSubmitForm`).
#
# The `respond` method sets the updated card for the app home. The caller
# automatically wraps the `Card` in the required `RenderActions` / `updateCard`
# structure.
#
# **Example:**
# ```ballerina
# remote function onSubmitForm(chat:ChatEvent event, chat:SubmitFormCaller caller) returns error? {
#     check caller->respond({
#         sections: [{
#             widgets: [{ textParagraph: { text: "Form submitted!" } }]
#         }]
#     });
# }
# ```
@display {label: "Google Chat Submit Form Caller"}
public isolated client class SubmitFormCaller {
    private final handle responseFuture;
    private boolean responded = false;

    # Initializes the SubmitFormCaller. Called internally by the dispatcher.
    isolated function init(handle responseFuture) {
        self.responseFuture = responseFuture;
    }

    # Sets the synchronous response with the updated app home card.
    #
    # The `Card` is automatically wrapped in the required response structure:
    # `{ renderActions: { action: { navigations: [{ updateCard: <card> }] } } }`
    #
    # + card - The updated card to display in the app home tab
    # + return - An error if respond has already been called
    remote isolated function respond(Card card) returns error? {
        lock {
            if self.responded {
                return error DispatchError("respond() has already been called for this event");
            }
            self.responded = true;
        }
        RenderActionsResponse renderResponse = {
            renderActions: {
                action: {
                    navigations: [{updateCard: card}]
                }
            }
        };
        json payload = renderResponse.toJson();
        completeFuture(self.responseFuture, payload);
    }

}

// ═══════════════════════════════════════════════════════════════════════════════
// WidgetUpdatedCaller — for onWidgetUpdated
// ═══════════════════════════════════════════════════════════════════════════════

# Caller for widget-updated events (`onWidgetUpdated`).
#
# The `respond` method sets the synchronous HTTP response with autocomplete
# suggestions or other widget update results.
#
# **Example:**
# ```ballerina
# remote function onWidgetUpdated(chat:ChatEvent event, chat:WidgetUpdatedCaller caller) returns error? {
#     check caller->respond({
#         actionResponse: {
#             'type: chat:UPDATE_WIDGET,
#             updatedWidget: { suggestions: { items: [{ text: "Option 1" }] } }
#         }
#     });
# }
# ```
@display {label: "Google Chat Widget Updated Caller"}
public isolated client class WidgetUpdatedCaller {
    private final handle responseFuture;
    private boolean responded = false;

    # Initializes the WidgetUpdatedCaller. Called internally by the dispatcher.
    isolated function init(handle responseFuture) {
        self.responseFuture = responseFuture;
    }

    # Sets the synchronous response with widget update results.
    #
    # + response - The message containing the widget update (typically with
    # `actionResponse.type = UPDATE_WIDGET`)
    # + return - An error if respond has already been called
    remote isolated function respond(Message response) returns error? {
        lock {
            if self.responded {
                return error DispatchError("respond() has already been called for this event");
            }
            self.responded = true;
        }
        json payload = response.toJson();
        completeFuture(self.responseFuture, payload);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Native Interop for ResponseFuture
// ═══════════════════════════════════════════════════════════════════════════════

# Creates a new ResponseFuture Java object.
#
# + return - A handle to the new `CompletableFuture`-backed ResponseFuture
isolated function createResponseFuture() returns handle = @java:Method {
    'class: "io.ballerina.lib.googleapis.chat.ResponseFuture"
} external;

# Signals the ResponseFuture with the response payload, unblocking the
# waiting resource function.
#
# + responseFuture - The handle to the ResponseFuture to complete
# + payload - The JSON response payload to deliver
isolated function completeFuture(handle responseFuture, json payload) = @java:Method {
    'class: "io.ballerina.lib.googleapis.chat.ResponseFuture"
} external;

# Blocks until the ResponseFuture is completed or the timeout expires.
# Returns the response payload as `json`, or `()` if timed out.
#
# + responseFuture - The handle to the ResponseFuture to wait on
# + timeoutSeconds - Maximum number of seconds to wait before returning `()`
# + return - The JSON payload set by `completeFuture`, or `()` on timeout
isolated function waitForResponse(handle responseFuture, int timeoutSeconds) returns json = @java:Method {
    name: "waitForResponseStatic",
    'class: "io.ballerina.lib.googleapis.chat.ResponseFuture"
} external;

// ═══════════════════════════════════════════════════════════════════════════════
// Utility Functions
// ═══════════════════════════════════════════════════════════════════════════════

isolated function resolveMessageId(string? messageId) returns string|error {
    if messageId !is string || messageId == "" {
        return error ClientError("Message name cannot be empty");
    }

    if messageId.indexOf("/") is int {
        string[] parts = re `/`.split(messageId);
        string lastPart = parts[parts.length() - 1];
        if lastPart == "" {
            return error ClientError("Invalid message ID or resource name: " + messageId);
        }
        return lastPart;
    }

    return messageId;
}
