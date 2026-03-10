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

import ballerina/test;

// ═══════════════════════════════════════════════════════════════════════════════
// Type Construction & Validation Tests
// ═══════════════════════════════════════════════════════════════════════════════

@test:Config {}
function testSpaceRecordCreation() {
    Space space = {
        name: "spaces/AAAAAA",
        spaceType: SPACE,
        displayName: "Test Space",
        singleUserBotDm: false,
        spaceThreadingState: THREADED_MESSAGES,
        externalUserAllowed: true
    };
    test:assertEquals(space.name, "spaces/AAAAAA");
    test:assertEquals(space.spaceType, SPACE);
    test:assertEquals(space.displayName, "Test Space");
    test:assertFalse(<boolean>space.singleUserBotDm);
    test:assertEquals(space.spaceThreadingState, THREADED_MESSAGES);
    test:assertTrue(<boolean>space.externalUserAllowed);
}

@test:Config {}
function testSpaceRecordWithOptionalFields() {
    Space space = {
        name: "spaces/BBBBBB"
    };
    test:assertEquals(space.name, "spaces/BBBBBB");
    test:assertEquals(space.spaceType, ());
    test:assertEquals(space.displayName, ());
    test:assertEquals(space.spaceDetails, ());
}

@test:Config {}
function testDirectMessageSpace() {
    Space space = {
        name: "spaces/DM123",
        spaceType: DIRECT_MESSAGE,
        singleUserBotDm: true
    };
    test:assertEquals(space.spaceType, DIRECT_MESSAGE);
    test:assertTrue(<boolean>space.singleUserBotDm);
}

@test:Config {}
function testGroupChatSpace() {
    Space space = {
        name: "spaces/GC456",
        spaceType: GROUP_CHAT
    };
    test:assertEquals(space.spaceType, GROUP_CHAT);
}

@test:Config {}
function testUserRecordCreation() {
    User user = {
        name: "users/123456",
        displayName: "Test User",
        domainId: "example.com",
        'type: HUMAN,
        isAnonymous: false
    };
    test:assertEquals(user.name, "users/123456");
    test:assertEquals(user.displayName, "Test User");
    test:assertEquals(user.'type, HUMAN);
    test:assertFalse(<boolean>user.isAnonymous);
}

@test:Config {}
function testBotUser() {
    User bot = {
        name: "users/bot-app",
        displayName: "My Bot",
        'type: BOT
    };
    test:assertEquals(bot.'type, BOT);
    test:assertEquals(bot.displayName, "My Bot");
}

@test:Config {}
function testChatThreadRecordCreation() {
    ChatThread thread = {
        name: "spaces/AAAAAA/threads/BBBBBB",
        threadKey: "my-thread-key"
    };
    test:assertEquals(thread.name, "spaces/AAAAAA/threads/BBBBBB");
    test:assertEquals(thread.threadKey, "my-thread-key");
}

@test:Config {}
function testMessageRecordCreation() {
    Message message = {
        name: "spaces/AAAAAA/messages/BBBBBB",
        sender: {
            name: "users/123",
            displayName: "Test User",
            'type: HUMAN
        },
        createTime: "2026-01-01T00:00:00Z",
        text: "Hello, World!",
        thread: {
            name: "spaces/AAAAAA/threads/CCCCCC"
        },
        space: {
            name: "spaces/AAAAAA",
            spaceType: SPACE
        }
    };
    test:assertEquals(message.name, "spaces/AAAAAA/messages/BBBBBB");
    test:assertEquals(message.text, "Hello, World!");
    test:assertEquals((<User>message.sender).displayName, "Test User");
    test:assertEquals((<User>message.sender).'type, HUMAN);
    test:assertEquals((<ChatThread>message.thread).name, "spaces/AAAAAA/threads/CCCCCC");
    test:assertEquals((<Space>message.space).name, "spaces/AAAAAA");
}

@test:Config {}
function testMessageWithCards() {
    Message message = {
        name: "spaces/AAAAAA/messages/CCCCCC",
        text: "Card message",
        cardsV2: [
            {
                cardId: "card-1",
                card: {
                    header: {
                        title: "Card Title",
                        subtitle: "Card Subtitle"
                    },
                    sections: [
                        {
                            header: "Section 1",
                            widgets: [
                                {
                                    textParagraph: {text: "Hello from the card!"}
                                }
                            ]
                        }
                    ]
                }
            }
        ]
    };
    test:assertEquals((<CardWithId[]>message.cardsV2).length(), 1);
    CardWithId cardWithId = (<CardWithId[]>message.cardsV2)[0];
    test:assertEquals(cardWithId.cardId, "card-1");
    test:assertEquals((<Card>cardWithId.card).header?.title, "Card Title");
}

@test:Config {}
function testCreateMessageRequest() {
    CreateMessageRequest request = {
        text: "Hello from bot!",
        thread: {
            threadKey: "my-thread"
        }
    };
    test:assertEquals(request.text, "Hello from bot!");
    test:assertEquals((<ChatThread>request.thread).threadKey, "my-thread");
}

@test:Config {}
function testMembershipRecordCreation() {
    Membership membership = {
        name: "spaces/AAAAAA/members/BBBBBB",
        state: JOINED,
        role: ROLE_MEMBER,
        member: {
            name: "users/123",
            displayName: "Test User",
            'type: HUMAN
        }
    };
    test:assertEquals(membership.name, "spaces/AAAAAA/members/BBBBBB");
    test:assertEquals(membership.state, JOINED);
    test:assertEquals(membership.role, ROLE_MEMBER);
    test:assertEquals((<User>membership.member).displayName, "Test User");
}

@test:Config {}
function testMembershipWithGroupMember() {
    Membership membership = {
        name: "spaces/AAAAAA/members/groups/GGG",
        state: JOINED,
        role: ROLE_MEMBER,
        groupMember: {
            name: "groups/GGG"
        }
    };
    test:assertEquals((<Group>membership.groupMember).name, "groups/GGG");
}

@test:Config {}
function testReactionRecordCreation() {
    Reaction reaction = {
        name: "spaces/AAAAAA/messages/BBBBBB/reactions/CCCCCC",
        user: {
            name: "users/123",
            'type: HUMAN
        },
        emoji: {
            unicode: "\u{1F44D}"
        }
    };
    test:assertEquals(reaction.name, "spaces/AAAAAA/messages/BBBBBB/reactions/CCCCCC");
    test:assertEquals((<Emoji>reaction.emoji).unicode, "\u{1F44D}");
}

@test:Config {}
function testReactionWithCustomEmoji() {
    Reaction reaction = {
        emoji: {
            customEmoji: {
                uid: "custom-emoji-123"
            }
        }
    };
    test:assertEquals((<Emoji>reaction.emoji).customEmoji?.uid, "custom-emoji-123");
}

@test:Config {}
function testAttachmentRecordCreation() {
    Attachment attachment = {
        name: "spaces/AAAAAA/messages/BBBBBB/attachments/CCCCCC",
        contentName: "document.pdf",
        contentType: "application/pdf",
        downloadUri: "https://example.com/download/doc.pdf"
    };
    test:assertEquals(attachment.name, "spaces/AAAAAA/messages/BBBBBB/attachments/CCCCCC");
    test:assertEquals(attachment.contentName, "document.pdf");
    test:assertEquals(attachment.contentType, "application/pdf");
}

@test:Config {}
function testAnnotationRecord() {
    ChatAnnotation chatAnnotation = {
        'type: USER_MENTION,
        startIndex: 0,
        length: 5,
        userMention: {
            user: {
                name: "users/123",
                displayName: "Test User"
            }
        }
    };
    test:assertEquals(chatAnnotation.'type, USER_MENTION);
    test:assertEquals(chatAnnotation.startIndex, 0);
    test:assertEquals(chatAnnotation.length, 5);
}

@test:Config {}
function testSlashCommandAnnotation() {
    ChatAnnotation chatAnnotation = {
        'type: SLASH_COMMAND,
        slashCommand: {
            commandName: "/help",
            commandId: 1
        }
    };
    test:assertEquals(chatAnnotation.'type, SLASH_COMMAND);
    test:assertEquals((<SlashCommandMetadata>chatAnnotation.slashCommand).commandName, "/help");
}

// ═══════════════════════════════════════════════════════════════════════════════
// List Response Tests
// ═══════════════════════════════════════════════════════════════════════════════

@test:Config {}
function testListSpacesResponse() {
    ListSpacesResponse response = {
        nextPageToken: "page-token-123",
        spaces: [
            {name: "spaces/AAA", spaceType: SPACE},
            {name: "spaces/BBB", spaceType: DIRECT_MESSAGE}
        ]
    };
    test:assertEquals(response.nextPageToken, "page-token-123");
    test:assertEquals((<Space[]>response.spaces).length(), 2);
}

@test:Config {}
function testListMessagesResponse() {
    ListMessagesResponse response = {
        messages: [
            {name: "spaces/AAA/messages/111", text: "msg1"},
            {name: "spaces/AAA/messages/222", text: "msg2"}
        ]
    };
    test:assertEquals((<Message[]>response.messages).length(), 2);
    test:assertEquals((<Message[]>response.messages)[0].text, "msg1");
}

@test:Config {}
function testListMembershipsResponse() {
    ListMembershipsResponse response = {
        memberships: [
            {name: "spaces/AAA/members/111", state: JOINED}
        ]
    };
    test:assertEquals((<Membership[]>response.memberships).length(), 1);
}

@test:Config {}
function testListReactionsResponse() {
    ListReactionsResponse response = {
        reactions: []
    };
    test:assertEquals((<Reaction[]>response.reactions).length(), 0);
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON Conversion Tests
// ═══════════════════════════════════════════════════════════════════════════════

@test:Config {}
function testChatEventFromJson() returns error? {
    json eventJson = {
        "type": "MESSAGE",
        "eventTime": "2026-01-01T00:00:00Z",
        "message": {
            "name": "spaces/AAA/messages/BBB",
            "text": "Hello bot!",
            "sender": {
                "name": "users/123",
                "displayName": "John",
                "type": "HUMAN"
            }
        },
        "user": {
            "name": "users/123",
            "displayName": "John",
            "type": "HUMAN"
        },
        "space": {
            "name": "spaces/AAA",
            "spaceType": "SPACE",
            "displayName": "General"
        }
    };
    ChatEvent event = check eventJson.cloneWithType(ChatEvent);
    test:assertEquals(event.'type, MESSAGE);
    test:assertEquals(event.eventTime, "2026-01-01T00:00:00Z");
    test:assertEquals((<Message>event.message).text, "Hello bot!");
    test:assertEquals((<User>event.user).displayName, "John");
    test:assertEquals((<Space>event.space).displayName, "General");
}

@test:Config {}
function testChatEventAddedToSpaceFromJson() returns error? {
    json eventJson = {
        "type": "ADDED_TO_SPACE",
        "eventTime": "2026-01-02T10:00:00Z",
        "user": {
            "name": "users/456",
            "displayName": "Jane",
            "type": "HUMAN"
        },
        "space": {
            "name": "spaces/XYZ",
            "spaceType": "GROUP_CHAT",
            "displayName": "Project Chat"
        }
    };
    ChatEvent event = check eventJson.cloneWithType(ChatEvent);
    test:assertEquals(event.'type, ADDED_TO_SPACE);
    test:assertEquals((<Space>event.space).spaceType, GROUP_CHAT);
}

@test:Config {}
function testChatEventCardClickedFromJson() returns error? {
    json eventJson = {
        "type": "CARD_CLICKED",
        "eventTime": "2026-01-03T15:30:00Z",
        "action": {
            "actionMethodName": "submitFeedback",
            "parameters": [
                {"key": "rating", "value": "5"}
            ]
        },
        "user": {
            "name": "users/789",
            "type": "HUMAN"
        },
        "space": {
            "name": "spaces/AAA"
        }
    };
    ChatEvent event = check eventJson.cloneWithType(ChatEvent);
    test:assertEquals(event.'type, CARD_CLICKED);
    test:assertEquals((<FormAction>event.action).actionMethodName, "submitFeedback");
    ActionParameter[] params = <ActionParameter[]>(<FormAction>event.action).parameters;
    test:assertEquals(params.length(), 1);
    test:assertEquals(params[0].'key, "rating");
    test:assertEquals(params[0].value, "5");
}

@test:Config {}
function testChatEventRemovedFromSpaceFromJson() returns error? {
    json eventJson = {
        "type": "REMOVED_FROM_SPACE",
        "space": {
            "name": "spaces/AAA",
            "spaceType": "SPACE"
        },
        "user": {
            "name": "users/123",
            "type": "HUMAN"
        }
    };
    ChatEvent event = check eventJson.cloneWithType(ChatEvent);
    test:assertEquals(event.'type, REMOVED_FROM_SPACE);
}

@test:Config {}
function testMessageFromJson() returns error? {
    json messageJson = {
        "name": "spaces/AAA/messages/BBB",
        "sender": {
            "name": "users/bot-123",
            "displayName": "My Bot",
            "type": "BOT"
        },
        "createTime": "2026-01-01T12:00:00Z",
        "text": "Bot reply",
        "threadReply": true,
        "thread": {
            "name": "spaces/AAA/threads/CCC",
            "threadKey": "conversation-1"
        }
    };
    Message message = check messageJson.cloneWithType(Message);
    test:assertEquals(message.name, "spaces/AAA/messages/BBB");
    test:assertEquals((<User>message.sender).'type, BOT);
    test:assertTrue(<boolean>message.threadReply);
    test:assertEquals((<ChatThread>message.thread).threadKey, "conversation-1");
}

@test:Config {}
function testSpaceFromJson() returns error? {
    json spaceJson = {
        "name": "spaces/AAAAAA",
        "spaceType": "SPACE",
        "displayName": "Engineering",
        "spaceThreadingState": "THREADED_MESSAGES",
        "spaceHistoryState": "HISTORY_ON",
        "spaceDetails": {
            "description": "Engineering team space",
            "guidelines": "Be respectful"
        }
    };
    Space space = check spaceJson.cloneWithType(Space);
    test:assertEquals(space.name, "spaces/AAAAAA");
    test:assertEquals(space.spaceType, SPACE);
    test:assertEquals(space.spaceThreadingState, THREADED_MESSAGES);
    test:assertEquals(space.spaceHistoryState, HISTORY_ON);
    test:assertEquals((<SpaceDetails>space.spaceDetails).description, "Engineering team space");
}

// ═══════════════════════════════════════════════════════════════════════════════
// Enum Value Tests
// ═══════════════════════════════════════════════════════════════════════════════

@test:Config {}
function testEventTypeEnum() {
    test:assertEquals(MESSAGE.toString(), "MESSAGE");
    test:assertEquals(ADDED_TO_SPACE.toString(), "ADDED_TO_SPACE");
    test:assertEquals(REMOVED_FROM_SPACE.toString(), "REMOVED_FROM_SPACE");
    test:assertEquals(CARD_CLICKED.toString(), "CARD_CLICKED");
    test:assertEquals(APP_HOME.toString(), "APP_HOME");
    test:assertEquals(SUBMIT_FORM.toString(), "SUBMIT_FORM");
}

@test:Config {}
function testSpaceTypeEnum() {
    test:assertEquals(SPACE.toString(), "SPACE");
    test:assertEquals(GROUP_CHAT.toString(), "GROUP_CHAT");
    test:assertEquals(DIRECT_MESSAGE.toString(), "DIRECT_MESSAGE");
}

@test:Config {}
function testUserTypeEnum() {
    test:assertEquals(HUMAN.toString(), "HUMAN");
    test:assertEquals(BOT.toString(), "BOT");
}

@test:Config {}
function testMembershipStateEnum() {
    test:assertEquals(JOINED.toString(), "JOINED");
    test:assertEquals(INVITED.toString(), "INVITED");
    test:assertEquals(NOT_A_MEMBER.toString(), "NOT_A_MEMBER");
}

@test:Config {}
function testMembershipRoleEnum() {
    test:assertEquals(ROLE_MEMBER.toString(), "ROLE_MEMBER");
    test:assertEquals(ROLE_MANAGER.toString(), "ROLE_MANAGER");
}

// ═══════════════════════════════════════════════════════════════════════════════
// Card Builder Tests
// ═══════════════════════════════════════════════════════════════════════════════

@test:Config {}
function testCardConstruction() {
    Card card = {
        header: {
            title: "Order Update",
            subtitle: "Order #12345",
            imageUrl: "https://example.com/icon.png",
            imageAltText: "Order icon"
        },
        sections: [
            {
                header: "Details",
                widgets: [
                    {
                        decoratedText: {
                            topLabel: "Status",
                            text: "Shipped",
                            wrapText: true
                        }
                    },
                    {
                        buttonList: {
                            buttons: [
                                {
                                    text: "Track Order",
                                    onClick: {
                                        openLink: {
                                            url: "https://example.com/track/12345"
                                        }
                                    }
                                }
                            ]
                        }
                    }
                ],
                collapsible: false
            }
        ]
    };
    test:assertEquals((<CardHeader>card.header).title, "Order Update");
    test:assertEquals((<Section[]>card.sections).length(), 1);
    Section section = (<Section[]>card.sections)[0];
    test:assertEquals(section.header, "Details");
    test:assertEquals((<Widget[]>section.widgets).length(), 2);
}

@test:Config {}
function testActionResponseDialog() {
    ActionResponse response = {
        'type: DIALOG,
        dialogAction: {
            dialog: {
                body: {
                    header: {title: "Feedback Form"},
                    sections: [
                        {
                            widgets: [
                                {textParagraph: {text: "Please rate your experience"}}
                            ]
                        }
                    ]
                }
            }
        }
    };
    test:assertEquals(response.'type, DIALOG);
    DialogAction dialogAction = <DialogAction>response.dialogAction;
    test:assertEquals((<Card>(<Dialog>dialogAction.dialog).body).header?.title, "Feedback Form");
}
