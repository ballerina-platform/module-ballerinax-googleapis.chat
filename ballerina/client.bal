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
import ballerina/jwt;

# Google Chat API client. Provides resource-based access to the Google Chat
# REST API v1 for managing spaces, messages, memberships, reactions, and
# attachments.
#
# Supports five authentication modes:
# - **Service Account PEM** (`ServiceAccountConfig`): For Chat bots with service account email plus PEM/private-key config
# - **Service Account Record** (`ServiceAccountCredentials`): For Chat bots with inline service account credentials
# - **Service Account File** (`ServiceAccountFileConfig`): For Chat bots with a JSON key file path
# - **OAuth2** (`OAuth2Config`): For user-authenticated access with auto token refresh
# - **Bearer Token** (`http:BearerTokenConfig`): For pre-obtained tokens
@display {label: "Google Chat", iconPath: "docs/icon.png"}
public isolated client class Client {
    final http:Client httpClient;

    # Initializes the Google Chat API client.
    #
    # + config - Connection configuration with authentication credentials
    # + serviceUrl - Base URL of the Google Chat API. Defaults to v1 endpoint.
    # + return - An error if client initialization fails
    public isolated function init(ConnectionConfig config,
            string serviceUrl = CHAT_API_BASE_URL)
        returns error? {
        http:ClientConfiguration httpClientConfig = {
            httpVersion: config.httpVersion,
            http1Settings: config.http1Settings,
            http2Settings: config.http2Settings,
            timeout: config.timeout,
            forwarded: config.forwarded,
            followRedirects: config.followRedirects,
            poolConfig: config.poolConfig,
            cache: config.cache,
            compression: config.compression,
            circuitBreaker: config.circuitBreaker,
            retryConfig: config.retryConfig,
            cookieConfig: config.cookieConfig,
            responseLimits: config.responseLimits,
            secureSocket: config.secureSocket,
            proxy: config.proxy,
            socketConfig: config.socketConfig,
            validation: config.validation,
            laxDataBinding: config.laxDataBinding
        };

        // Configure auth based on the provided config type
        if config.auth is http:BearerTokenConfig {
            httpClientConfig.auth = <http:BearerTokenConfig>config.auth;
        } else if config.auth is OAuth2Config {
            OAuth2Config oauthConfig = <OAuth2Config>config.auth;
            httpClientConfig.auth = <http:OAuth2RefreshTokenGrantConfig>{
                clientId: oauthConfig.clientId,
                clientSecret: oauthConfig.clientSecret,
                refreshUrl: oauthConfig.refreshUrl,
                refreshToken: oauthConfig.refreshToken
            };
        } else {
            // Service account auth — use JWT Bearer Grant (RFC 7523) to exchange
            // a signed JWT assertion for an OAuth2 access token. Google Chat API
            // requires a proper OAuth2 Bearer token, not a raw self-signed JWT.
            NormalizedServiceAccount saConfig = check normalizeServiceAccountAuth(<ServiceAccountAuthConfig>config.auth);
            jwt:IssuerConfig assertionConfig = {
                issuer: saConfig.issuer,
                username: saConfig.issuer,
                audience: GOOGLE_OAUTH2_TOKEN_URL,
                expTime: 3600,
                signatureConfig: saConfig.signatureConfig,
                customClaims: {"scope": CHAT_BOT_SCOPE}
            };
            string assertion = check jwt:issue(assertionConfig);
            httpClientConfig.auth = <http:OAuth2JwtBearerGrantConfig>{
                tokenUrl: GOOGLE_OAUTH2_TOKEN_URL,
                assertion: assertion
            };
        }

        self.httpClient = check new (serviceUrl, httpClientConfig);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Spaces
    // ═════════════════════════════════════════════════════════════════════════

    # Lists spaces the caller is a member of.
    #
    # + queries - Query parameters for filtering and pagination
    # + return - A list of spaces or an error
    resource isolated function get spaces(
            *ListSpacesQueries queries) returns ListSpacesResponse|error {
        string path = "/spaces";
        map<string|string[]> queryParams = {};
        if queries.pageSize is int {
            queryParams["pageSize"] = queries.pageSize.toString();
        }
        if queries.pageToken is string {
            queryParams["pageToken"] = <string>queries.pageToken;
        }
        if queries.filter is string {
            queryParams["filter"] = <string>queries.filter;
        }
        return self.httpClient->get(path, targetType = ListSpacesResponse);
    }

    # Creates a named space (requires user authentication).
    #
    # + payload - The space to create
    # + return - The created space or an error
    resource isolated function post spaces(
            Space payload) returns Space|error {
        return self.httpClient->post("/spaces", payload, targetType = Space);
    }

    # Returns details about a space.
    #
    # + spaceId - The ID of the space (from the `name` field, e.g., "AAAAAA")
    # + return - The space details or an error
    resource isolated function get spaces/[string spaceId]() returns Space|error {
        string path = "/spaces/" + spaceId;
        return self.httpClient->get(path, targetType = Space);
    }

    # Updates a space.
    #
    # + spaceId - The ID of the space to update
    # + payload - The updated space fields
    # + queries - Query parameters (updateMask)
    # + return - The updated space or an error
    resource isolated function patch spaces/[string spaceId](
            Space payload,
            *UpdateSpaceQueries queries) returns Space|error {
        string path = "/spaces/" + spaceId;
        if queries.updateMask is string {
            path = path + "?updateMask=" + <string>queries.updateMask;
        }
        return self.httpClient->patch(path, payload, targetType = Space);
    }

    # Deletes a named space.
    #
    # + spaceId - The ID of the space to delete
    # + return - An error if the operation fails
    resource isolated function delete spaces/[string spaceId]() returns error? {
        string path = "/spaces/" + spaceId;
        http:Response _ = check self.httpClient->delete(path);
    }

    # Finds an existing direct message space with a specified user.
    #
    # + queries - Query parameters containing the user's resource name
    # + return - The direct message space or an error
    resource isolated function get spaces/findDirectMessage(
            *FindDirectMessageQueries queries) returns Space|error {
        string path = "/spaces:findDirectMessage";
        if queries.name is string {
            path = path + "?name=" + <string>queries.name;
        }
        return self.httpClient->get(path, targetType = Space);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Messages
    // ═════════════════════════════════════════════════════════════════════════

    # Creates a message in a Google Chat space.
    #
    # + spaceId - The ID of the space to post the message in
    # + payload - The message to create
    # + queries - Query parameters for threading and idempotency
    # + return - The created message or an error
    resource isolated function post spaces/[string spaceId]/messages(
            CreateMessageRequest payload,
            *CreateMessageQueries queries) returns Message|error {
        string path = "/spaces/" + spaceId + "/messages";
        string[] queryParts = [];
        if queries.threadKey is string {
            queryParts.push("threadKey=" + <string>queries.threadKey);
        }
        if queries.requestId is string {
            queryParts.push("requestId=" + <string>queries.requestId);
        }
        if queries.messageReplyOption is string {
            queryParts.push("messageReplyOption=" + <string>queries.messageReplyOption);
        }
        if queries.messageId is string {
            queryParts.push("messageId=" + <string>queries.messageId);
        }
        if queryParts.length() > 0 {
            path = path + "?" + string:'join("&", ...queryParts);
        }
        return self.httpClient->post(path, payload, targetType = Message);
    }

    # Lists messages in a space.
    #
    # + spaceId - The ID of the space
    # + queries - Query parameters for filtering, ordering, and pagination
    # + return - A list of messages or an error
    resource isolated function get spaces/[string spaceId]/messages(
            *ListMessagesQueries queries) returns ListMessagesResponse|error {
        string path = "/spaces/" + spaceId + "/messages";
        return self.httpClient->get(path, targetType = ListMessagesResponse);
    }

    # Returns details about a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + return - The message or an error
    resource isolated function get spaces/[string spaceId]/messages/[string messageId]()
            returns Message|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId;
        return self.httpClient->get(path, targetType = Message);
    }

    # Updates a message. Allows updating the text, cards, and attachments.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message to update
    # + payload - The updated message fields
    # + queries - Query parameters (updateMask, allowMissing)
    # + return - The updated message or an error
    resource isolated function put spaces/[string spaceId]/messages/[string messageId](
            UpdateMessageRequest payload,
            *UpdateMessageQueries queries) returns Message|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId;
        string[] queryParts = [];
        if queries.updateMask is string {
            queryParts.push("updateMask=" + <string>queries.updateMask);
        }
        if queries.allowMissing is boolean {
            queryParts.push("allowMissing=" + (<boolean>queries.allowMissing).toString());
        }
        if queryParts.length() > 0 {
            path = path + "?" + string:'join("&", ...queryParts);
        }
        return self.httpClient->put(path, payload, targetType = Message);
    }

    # Deletes a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message to delete
    # + return - An error if the operation fails
    resource isolated function delete spaces/[string spaceId]/messages/[string messageId]()
            returns error? {
        string path = "/spaces/" + spaceId + "/messages/" + messageId;
        http:Response _ = check self.httpClient->delete(path);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Memberships
    // ═════════════════════════════════════════════════════════════════════════

    # Creates a membership (adds a user or Chat app to a space).
    #
    # + spaceId - The ID of the space
    # + payload - The membership to create
    # + return - The created membership or an error
    resource isolated function post spaces/[string spaceId]/members(
            Membership payload) returns Membership|error {
        string path = "/spaces/" + spaceId + "/members";
        return self.httpClient->post(path, payload, targetType = Membership);
    }

    # Lists memberships in a space.
    #
    # + spaceId - The ID of the space
    # + queries - Query parameters for filtering and pagination
    # + return - A list of memberships or an error
    resource isolated function get spaces/[string spaceId]/members(
            *ListMembershipsQueries queries) returns ListMembershipsResponse|error {
        string path = "/spaces/" + spaceId + "/members";
        return self.httpClient->get(path, targetType = ListMembershipsResponse);
    }

    # Returns details about a membership.
    #
    # + spaceId - The ID of the space
    # + memberId - The ID of the member
    # + return - The membership or an error
    resource isolated function get spaces/[string spaceId]/members/[string memberId]()
            returns Membership|error {
        string path = "/spaces/" + spaceId + "/members/" + memberId;
        return self.httpClient->get(path, targetType = Membership);
    }

    # Deletes a membership (removes a user or Chat app from a space).
    #
    # + spaceId - The ID of the space
    # + memberId - The ID of the member to remove
    # + return - An error if the operation fails
    resource isolated function delete spaces/[string spaceId]/members/[string memberId]()
            returns error? {
        string path = "/spaces/" + spaceId + "/members/" + memberId;
        http:Response _ = check self.httpClient->delete(path);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Reactions
    // ═════════════════════════════════════════════════════════════════════════

    # Creates a reaction on a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + payload - The reaction to create
    # + return - The created reaction or an error
    resource isolated function post spaces/[string spaceId]/messages/[string messageId]/reactions(
            Reaction payload) returns Reaction|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId + "/reactions";
        return self.httpClient->post(path, payload, targetType = Reaction);
    }

    # Lists reactions on a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + queries - Query parameters for filtering and pagination
    # + return - A list of reactions or an error
    resource isolated function get spaces/[string spaceId]/messages/[string messageId]/reactions(
            *ListReactionsQueries queries) returns ListReactionsResponse|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId + "/reactions";
        return self.httpClient->get(path, targetType = ListReactionsResponse);
    }

    # Deletes a reaction from a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + reactionId - The ID of the reaction to delete
    # + return - An error if the operation fails
    resource isolated function delete spaces/[string spaceId]/messages/[string messageId]/reactions/[string reactionId]()
            returns error? {
        string path = "/spaces/" + spaceId + "/messages/" + messageId + "/reactions/" + reactionId;
        http:Response _ = check self.httpClient->delete(path);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Attachments
    // ═════════════════════════════════════════════════════════════════════════

    # Gets the metadata of a message attachment.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + attachmentId - The ID of the attachment
    # + return - The attachment metadata or an error
    resource isolated function get spaces/[string spaceId]/messages/[string messageId]/attachments/[string attachmentId]()
            returns Attachment|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId + "/attachments/" + attachmentId;
        return self.httpClient->get(path, targetType = Attachment);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Space Events
    // ═════════════════════════════════════════════════════════════════════════

    # Returns an event from a Google Chat space.
    #
    # + spaceId - The ID of the space
    # + spaceEventId - The ID of the space event
    # + return - The space event or an error
    resource isolated function get spaces/[string spaceId]/spaceEvents/[string spaceEventId]()
            returns SpaceEvent|error {
        string path = "/spaces/" + spaceId + "/spaceEvents/" + spaceEventId;
        return self.httpClient->get(path, targetType = SpaceEvent);
    }

    # Lists events from a Google Chat space.
    #
    # + spaceId - The ID of the space
    # + queries - Query parameters (filter is required for event type)
    # + return - A list of space events or an error
    resource isolated function get spaces/[string spaceId]/spaceEvents(
            *ListSpaceEventsQueries queries) returns ListSpaceEventsResponse|error {
        string path = "/spaces/" + spaceId + "/spaceEvents";
        string[] queryParts = [];
        queryParts.push("filter=" + queries.filter);
        if queries.pageSize is int {
            queryParts.push("pageSize=" + (<int>queries.pageSize).toString());
        }
        if queries.pageToken is string {
            queryParts.push("pageToken=" + <string>queries.pageToken);
        }
        path = path + "?" + string:'join("&", ...queryParts);
        return self.httpClient->get(path, targetType = ListSpaceEventsResponse);
    }
}
