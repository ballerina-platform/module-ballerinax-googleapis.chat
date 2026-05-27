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

// ═══════════════════════════════════════════════════════════════════════════════
// In-process mock of the Google Chat REST API.
//
// The connector `Client` is pointed at this server (see `MOCK_SERVICE_URL`) so the
// client resource methods and the Caller async methods (sendMessage, updateMessage,
// deleteMessage, getSpace) can be exercised without hitting the live Chat API or
// requiring credentials. The connector uses a bearer-token config in tests, so the
// HTTP client attaches the Authorization header itself — the mock does not validate
// it.
//
// Returned records are intentionally minimal; every field on the Chat response
// records is optional, so a small payload binds cleanly via `cloneWithType`.
// ═══════════════════════════════════════════════════════════════════════════════

const int MOCK_PORT = 9091;
final string MOCK_SERVICE_URL = string `http://localhost:${MOCK_PORT}`;

listener http:Listener mockChatServer = new (MOCK_PORT);

service http:Service / on mockChatServer {

    // ─── Spaces (single-segment paths, incl. the `spaces:<verb>` action endpoints) ──

    # Handles `GET /spaces` (list), `GET /spaces:search`, and
    # `GET /spaces:findDirectMessage`. Google encodes these as one path segment.
    # Unknown actions return 404 so tests fail on route drift rather than passing.
    resource function get [string action]() returns json|http:NotFound {
        match action {
            "spaces" => {
                return {spaces: [{name: "spaces/AAAAAAA", displayName: "Mock Space"}], nextPageToken: ""};
            }
            "spaces:search" => {
                return {spaces: [{name: "spaces/AAAAAAA"}], totalSize: 1, nextPageToken: ""};
            }
            "spaces:findDirectMessage" => {
                return {name: "spaces/DM12345", spaceType: "DIRECT_MESSAGE"};
            }
        }
        return <http:NotFound>{body: {"error": "unsupported action: " + action}};
    }

    # Handles `POST /spaces` (create) and `POST /spaces:setup`.
    resource function post [string action](@http:Payload json payload) returns json|http:NotFound {
        if action == "spaces" || action == "spaces:setup" {
            return {name: "spaces/AAAAAAA", displayName: "Mock Space"};
        }
        return <http:NotFound>{body: {"error": "unsupported action: " + action}};
    }

    resource function get spaces/[string spaceId]() returns json {
        return {name: "spaces/" + spaceId, displayName: "Mock Space", spaceType: "SPACE"};
    }

    resource function patch spaces/[string spaceId](@http:Payload json payload) returns json {
        return {name: "spaces/" + spaceId, displayName: "Updated Space"};
    }

    resource function delete spaces/[string spaceId]() returns http:Ok {
        return {body: {}};
    }

    // ─── Messages ───────────────────────────────────────────────────────────────

    resource function post spaces/[string spaceId]/messages(@http:Payload json payload) returns json {
        return {name: "spaces/" + spaceId + "/messages/MSG123", text: "created"};
    }

    resource function get spaces/[string spaceId]/messages() returns json {
        return {messages: [{name: "spaces/" + spaceId + "/messages/MSG123", text: "hello"}], nextPageToken: ""};
    }

    resource function get spaces/[string spaceId]/messages/[string messageId]() returns json {
        return {name: "spaces/" + spaceId + "/messages/" + messageId, text: "hello"};
    }

    resource function patch spaces/[string spaceId]/messages/[string messageId](@http:Payload json payload)
            returns json {
        return {name: "spaces/" + spaceId + "/messages/" + messageId, text: "updated"};
    }

    resource function delete spaces/[string spaceId]/messages/[string messageId]() returns http:Ok {
        return {body: {}};
    }

    // ─── Memberships ──────────────────────────────────────────────────────────────

    resource function post spaces/[string spaceId]/members(@http:Payload json payload) returns json {
        return {name: "spaces/" + spaceId + "/members/MEM123", state: "JOINED", role: "ROLE_MEMBER"};
    }

    resource function get spaces/[string spaceId]/members() returns json {
        return {
            memberships: [
                {
                    name: "spaces/" + spaceId + "/members/MEM123",
                    state: "JOINED",
                    role: "ROLE_MEMBER",
                    member: {name: "users/USER123", "type": "HUMAN"}
                }
            ],
            nextPageToken: ""
        };
    }

    resource function get spaces/[string spaceId]/members/[string memberId]() returns json {
        return {name: "spaces/" + spaceId + "/members/" + memberId, state: "JOINED", role: "ROLE_MEMBER"};
    }

    resource function patch spaces/[string spaceId]/members/[string memberId](@http:Payload json payload)
            returns json {
        return {name: "spaces/" + spaceId + "/members/" + memberId, role: "ROLE_MANAGER"};
    }

    resource function delete spaces/[string spaceId]/members/[string memberId]() returns http:Ok {
        return {body: {}};
    }

    // ─── Reactions ────────────────────────────────────────────────────────────────

    resource function post spaces/[string spaceId]/messages/[string messageId]/reactions(@http:Payload json payload)
            returns json {
        return {
            name: "spaces/" + spaceId + "/messages/" + messageId + "/reactions/RCT123",
            user: {name: "users/USER123", "type": "HUMAN"},
            emoji: {unicode: "👍"}
        };
    }

    resource function get spaces/[string spaceId]/messages/[string messageId]/reactions() returns json {
        return {
            reactions: [
                {
                    name: "spaces/" + spaceId + "/messages/" + messageId + "/reactions/RCT123",
                    user: {name: "users/USER123", "type": "HUMAN"},
                    emoji: {unicode: "👍"}
                }
            ],
            nextPageToken: ""
        };
    }

    resource function delete spaces/[string spaceId]/messages/[string messageId]/reactions/[string reactionId]()
            returns http:Ok {
        return {body: {}};
    }

    // ─── Attachments (metadata) + media download ────────────────────────────────────

    resource function get spaces/[string spaceId]/messages/[string messageId]/attachments/[string attachmentId]()
            returns json {
        return {
            name: "spaces/" + spaceId + "/messages/" + messageId + "/attachments/" + attachmentId,
            contentName: "file.txt",
            contentType: "text/plain"
        };
    }

    resource function get media/[string resourceName]() returns http:Ok {
        return {body: "mock-bytes".toBytes(), mediaType: "application/octet-stream"};
    }

    // ─── Space events ───────────────────────────────────────────────────────────────

    resource function get spaces/[string spaceId]/spaceEvents() returns json {
        return {
            spaceEvents: [
                {
                    name: "spaces/" + spaceId + "/spaceEvents/EVT123",
                    eventType: "google.workspace.chat.message.v1.created"
                }
            ],
            nextPageToken: ""
        };
    }

    resource function get spaces/[string spaceId]/spaceEvents/[string spaceEventId]() returns json {
        return {
            name: "spaces/" + spaceId + "/spaceEvents/" + spaceEventId,
            eventType: "google.workspace.chat.message.v1.created"
        };
    }
}
