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
import ballerina/test;

// ═══════════════════════════════════════════════════════════════════════════════
// Client tests — exercise the Chat API client against the in-process mock server.
// ═══════════════════════════════════════════════════════════════════════════════

// A Client wired to the mock server with a dummy bearer token. The mock does not
// validate the token; it only needs to be present so the HTTP client attaches it.
final Client mockClient = check new ({auth: <http:BearerTokenConfig>{token: "test-token"}}, MOCK_SERVICE_URL);

const string TEST_SPACE = "AAAAAAA";
const string TEST_MESSAGE = "MSG123";

// ─── Spaces ──────────────────────────────────────────────────────────────────────

@test:Config {}
function testClientListSpaces() returns error? {
    ListSpacesResponse response = check mockClient->/spaces();
    test:assertTrue(response.spaces is Space[]);
    test:assertEquals((<Space[]>response.spaces).length(), 1);
}

@test:Config {}
function testClientCreateSpace() returns error? {
    Space space = check mockClient->/spaces.post({displayName: "New Space"});
    test:assertEquals(space.name, "spaces/AAAAAAA");
}

@test:Config {}
function testClientGetSpace() returns error? {
    Space space = check mockClient->/spaces/[TEST_SPACE];
    test:assertEquals(space.name, "spaces/" + TEST_SPACE);
}

@test:Config {}
function testClientUpdateSpace() returns error? {
    Space space = check mockClient->/spaces/[TEST_SPACE].patch({displayName: "Renamed"}, updateMask = "displayName");
    test:assertEquals(space.displayName, "Updated Space");
}

@test:Config {}
function testClientDeleteSpace() returns error? {
    check mockClient->/spaces/[TEST_SPACE].delete();
}

@test:Config {}
function testClientFindDirectMessage() returns error? {
    Space space = check mockClient->/spaces/findDirectMessage(name = "users/123");
    test:assertEquals(space.spaceType, DIRECT_MESSAGE);
}

@test:Config {}
function testClientSearchSpaces() returns error? {
    SearchSpacesResponse response = check mockClient->/spaces/search(query = "spaceType = \"SPACE\"");
    test:assertEquals(response.totalSize, 1);
}

@test:Config {}
function testClientSetupSpace() returns error? {
    Space space = check mockClient->/spaces/setup.post({space: {spaceType: SPACE, displayName: "S"}});
    test:assertEquals(space.name, "spaces/AAAAAAA");
}

// ─── Messages ──────────────────────────────────────────────────────────────────────

@test:Config {}
function testClientCreateMessage() returns error? {
    Message message = check mockClient->/spaces/[TEST_SPACE]/messages.post({text: "hi"});
    test:assertEquals(message.text, "created");
}

@test:Config {}
function testClientListMessages() returns error? {
    ListMessagesResponse response = check mockClient->/spaces/[TEST_SPACE]/messages();
    test:assertEquals((<Message[]>response.messages).length(), 1);
}

@test:Config {}
function testClientGetMessage() returns error? {
    Message message = check mockClient->/spaces/[TEST_SPACE]/messages/[TEST_MESSAGE];
    test:assertEquals(message.text, "hello");
}

@test:Config {}
function testClientUpdateMessage() returns error? {
    Message message = check mockClient->/spaces/[TEST_SPACE]/messages/[TEST_MESSAGE].patch(
        {text: "new"}, updateMask = "text");
    test:assertEquals(message.text, "updated");
}

@test:Config {}
function testClientDeleteMessage() returns error? {
    check mockClient->/spaces/[TEST_SPACE]/messages/[TEST_MESSAGE].delete();
}

// ─── Memberships ────────────────────────────────────────────────────────────────────

@test:Config {}
function testClientCreateMembership() returns error? {
    Membership membership = check mockClient->/spaces/[TEST_SPACE]/members.post({member: {name: "users/1"}});
    test:assertEquals(membership.state, JOINED);
}

@test:Config {}
function testClientListMemberships() returns error? {
    ListMembershipsResponse response = check mockClient->/spaces/[TEST_SPACE]/members();
    test:assertEquals((<Membership[]>response.memberships).length(), 1);
}

@test:Config {}
function testClientGetMembership() returns error? {
    Membership membership = check mockClient->/spaces/[TEST_SPACE]/members/["MEM123"];
    test:assertEquals(membership.role, ROLE_MEMBER);
}

@test:Config {}
function testClientUpdateMembership() returns error? {
    Membership membership = check mockClient->/spaces/[TEST_SPACE]/members/["MEM123"].patch(
        {role: ROLE_MANAGER}, updateMask = "role");
    test:assertEquals(membership.role, ROLE_MANAGER);
}

@test:Config {}
function testClientDeleteMembership() returns error? {
    check mockClient->/spaces/[TEST_SPACE]/members/["MEM123"].delete();
}

// ─── Reactions ──────────────────────────────────────────────────────────────────────

@test:Config {}
function testClientCreateReaction() returns error? {
    Reaction reaction = check mockClient->/spaces/[TEST_SPACE]/messages/[TEST_MESSAGE]/reactions.post(
        {emoji: {unicode: "👍"}});
    test:assertTrue(reaction.name is string);
}

@test:Config {}
function testClientListReactions() returns error? {
    ListReactionsResponse response = check mockClient->/spaces/[TEST_SPACE]/messages/[TEST_MESSAGE]/reactions();
    test:assertEquals((<Reaction[]>response.reactions).length(), 1);
}

@test:Config {}
function testClientDeleteReaction() returns error? {
    check mockClient->/spaces/[TEST_SPACE]/messages/[TEST_MESSAGE]/reactions/["RCT123"].delete();
}

// ─── Attachments + media ──────────────────────────────────────────────────────────────

@test:Config {}
function testClientGetAttachment() returns error? {
    Attachment attachment = check mockClient->/spaces/[TEST_SPACE]/messages/[TEST_MESSAGE]/attachments/["ATT123"];
    test:assertEquals(attachment.contentType, "text/plain");
}

@test:Config {}
function testClientDownloadMedia() returns error? {
    byte[] bytes = check mockClient->downloadMedia("mock-resource");
    test:assertTrue(bytes.length() > 0);
}

// ─── Space events ──────────────────────────────────────────────────────────────────────

@test:Config {}
function testClientListSpaceEvents() returns error? {
    ListSpaceEventsResponse response = check mockClient->/spaces/[TEST_SPACE]/spaceEvents(
        filter = "event_types:\"google.workspace.chat.message.v1.created\"");
    test:assertEquals((<SpaceEvent[]>response.spaceEvents).length(), 1);
}

@test:Config {}
function testClientGetSpaceEvent() returns error? {
    SpaceEvent event = check mockClient->/spaces/[TEST_SPACE]/spaceEvents/["EVT123"];
    test:assertEquals(event.name, "spaces/" + TEST_SPACE + "/spaceEvents/EVT123");
}
