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

# High-level client for responding to Google Chat events.
#
# A `Caller` is automatically created and injected by the listener's dispatcher
# when a `ChatService` remote function includes it as a parameter. It is
# pre-configured with the space and message context from the triggering event,
# so you can respond without manually extracting IDs.
#
# **Example:**
# ```ballerina
# remote function onMessage(googlechat:ChatEvent event, googlechat:Caller caller) returns error? {
#     googlechat:Message sent = check caller->reply("Got your message!");
#     sent.text = "Updated";
#     check caller->updateMessage(sent, updateMask = "text");
# }
# ```
#
# The `Caller` only exposes operations supported for Chat app authentication.
# It wraps an internal `googlechat:Client` with credentials from the listener
# configuration. You do **not** need to create a separate client.
@display {label: "Google Chat Caller"}
public isolated client class Caller {
    private final Client chatClient;
    private final string spaceId;

    # Initializes the Caller. This is called internally by the native dispatcher;
    # users should not create `Caller` instances directly.
    #
    # + chatClient - An authenticated Google Chat API client
    # + spaceId - The ID of the space where the event occurred
    isolated function init(Client chatClient, string spaceId) {
        self.chatClient = chatClient;
        self.spaceId = spaceId;
    }

    # Replies with a plain-text message in the same space where the event occurred.
    #
    # + text - The text content to send
    # + return - The created message or an error
    remote isolated function reply(string text) returns Message|error {
        return self.chatClient->/spaces/[self.spaceId]/messages.post({
            text: text
        });
    }

    # Replies with one or more cards in the same space where the event occurred.
    #
    # + cards - The cards to send (Cards V2 format)
    # + return - The created message or an error
    remote isolated function replyWithCard(CardWithId[] cards) returns Message|error {
        return self.chatClient->/spaces/[self.spaceId]/messages.post({
            cardsV2: cards
        });
    }

    # Sends a fully customizable message to the same space where the event occurred.
    #
    # Use this when you need to send text with cards, accessory widgets, threading,
    # or other advanced options beyond what the `reply` method provides.
    #
    # + message - The message payload to send
    # + return - The created message or an error
    remote isolated function sendMessage(CreateMessageRequest message) returns Message|error {
        return self.chatClient->/spaces/[self.spaceId]/messages.post(message);
    }

    # Updates a bot-accessible message in the same space.
    #
    # The `message.name` field must be present. It can be either the full resource
    # name (for example `spaces/AAA/messages/abc123`) or just the leaf message ID
    # (for example `abc123`).
    #
    # + message - The message to update. Its `name` identifies the target message,
    #             and the updatable fields provide the new content.
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
        if queries.updateMask is string {
            if queries.allowMissing is boolean {
                return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].put(
                    request,
                    updateMask = <string>queries.updateMask,
                    allowMissing = <boolean>queries.allowMissing
                );
            }
            return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].put(
                request,
                updateMask = <string>queries.updateMask
            );
        }

        if queries.allowMissing is boolean {
            return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].put(
                request,
                allowMissing = <boolean>queries.allowMissing
            );
        }

        return self.chatClient->/spaces/[self.spaceId]/messages/[resolvedMessageId].put(request);
    }

    # Deletes a bot-accessible message in the same space.
    #
    # The `message.name` field must be present. It can be either the full resource
    # name (for example `spaces/AAA/messages/abc123`) or just the leaf message ID
    # (for example `abc123`).
    #
    # + message - The message to delete. Its `name` identifies the target message.
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
