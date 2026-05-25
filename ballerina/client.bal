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
import ballerina/mime;
import ballerina/url;

# Google Chat API client. Provides resource-based access to the Google Chat
# REST API v1 for managing spaces, messages, memberships, reactions, and
# attachments.
#
# Supports four authentication modes:
# - **Service Account Record** (`ServiceAccountCredentials`): For Chat bots with inline service account credentials
# - **Service Account File** (`ServiceAccountFileConfig`): For Chat bots with a JSON key file path
# - **OAuth2** (`OAuth2Config`): For user-authenticated access with auto token refresh
# - **Bearer Token** (`http:BearerTokenConfig`): For pre-obtained tokens
#
# For service-account auth, the client manages its own access token: it self-signs
# a JWT assertion, exchanges it at Google's OAuth2 token endpoint, caches the
# resulting access token, and refreshes it transparently before expiry.
@display {label: "Google Chat", iconPath: "docs/icon.png"}
public isolated client class Client {
    final http:Client httpClient;
    final http:Client uploadHttpClient;
    final ServiceAccountTokenProvider? tokenProvider;

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

        // Configure auth based on the provided config type. For service-account
        // auth we leave `httpClientConfig.auth` unset and inject the
        // Authorization header per request via `self.tokenProvider` instead —
        // this lets us self-refresh past Google's 1h JWT assertion cap.
        ServiceAccountTokenProvider? provider = ();
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
            ServiceAccountKeyMaterial keyMaterial =
                check normalizeServiceAccountAuth(<ServiceAccountAuthConfig>config.auth);
            provider = check new ServiceAccountTokenProvider(
                keyMaterial.issuer, keyMaterial.pemPrivateKey, CHAT_BOT_SCOPE
            );
        }

        self.tokenProvider = provider;
        self.httpClient = check new (serviceUrl, httpClientConfig);
        self.uploadHttpClient = check new (resolveUploadServiceUrl(serviceUrl), httpClientConfig);
    }

    # Returns the auth headers to attach to outgoing requests. For service-account
    # mode this contains the (auto-refreshed) `Authorization: Bearer <token>`
    # header. For OAuth2 / BearerToken modes the underlying http client handles
    # auth, so this returns `()`.
    #
    # + return - A header map with the bearer token, `()` if the underlying
    # http client handles auth, or an error if a service-account token refresh fails
    private isolated function authHeaders() returns map<string|string[]>?|error {
        ServiceAccountTokenProvider? provider = self.tokenProvider;
        if provider is () {
            return ();
        }
        string token = check provider.getAccessToken();
        return {"Authorization": "Bearer " + token};
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
        string path = "/spaces" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = ListSpacesResponse);
    }

    # Creates a named space (requires user authentication).
    #
    # + payload - The space to create
    # + return - The created space or an error
    resource isolated function post spaces(
            Space payload) returns Space|error {
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->post("/spaces", payload, headers, targetType = Space);
    }

    # Returns details about a space.
    #
    # + spaceId - The ID of the space (from the `name` field, e.g., "AAAAAA")
    # + return - The space details or an error
    resource isolated function get spaces/[string spaceId]() returns Space|error {
        string path = "/spaces/" + spaceId;
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = Space);
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
        string path = "/spaces/" + spaceId + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->patch(path, payload, headers, targetType = Space);
    }

    # Deletes a named space.
    #
    # + spaceId - The ID of the space to delete
    # + return - An error if the operation fails
    resource isolated function delete spaces/[string spaceId]() returns error? {
        string path = "/spaces/" + spaceId;
        map<string|string[]>? headers = check self.authHeaders();
        http:Response _ = check self.httpClient->delete(path, headers = headers);
    }

    # Finds an existing direct message space with a specified user.
    #
    # + queries - Query parameters containing the user's resource name
    # + return - The direct message space or an error
    resource isolated function get spaces/findDirectMessage(
            *FindDirectMessageQueries queries) returns Space|error {
        string path = "/spaces:findDirectMessage" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = Space);
    }

    # Searches for spaces in a Google Workspace organization (requires admin access).
    #
    # Returns a paginated list of spaces matching the given query. The caller must
    # be a Google Workspace administrator with the manage chat and spaces conversations
    # privilege. Set `useAdminAccess` to `true` in the query parameters.
    #
    # Requires the `chat.admin.spaces` or `chat.admin.spaces.readonly` OAuth scope.
    #
    # + queries - Query parameters including the required `query` field and optional
    # `useAdminAccess`, `pageSize`, `pageToken`, and `orderBy`
    # + return - A paginated list of matching spaces or an error
    resource isolated function get spaces/search(
            *SearchSpacesQueries queries) returns SearchSpacesResponse|error {
        string path = "/spaces:search" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = SearchSpacesResponse);
    }

    # Creates a space and adds specified users or Google Groups to it.
    #
    # The calling user is automatically added to the space and should not be
    # specified in the memberships list. Supports creating named spaces,
    # group chats, and direct messages (including DMs with the calling app).
    #
    # Requires user authentication with the `chat.spaces` or
    # `chat.spaces.create` OAuth scope.
    #
    # + payload - The setup request containing the space definition and optional
    # initial memberships and idempotency request ID
    # + return - The created (or existing, for DMs) space or an error
    resource isolated function post spaces/setup(
            SetUpSpaceRequest payload) returns Space|error {
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->post("/spaces:setup", payload, headers, targetType = Space);
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
        string path = "/spaces/" + spaceId + "/messages" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->post(path, payload, headers, targetType = Message);
    }

    # Lists messages in a space.
    #
    # + spaceId - The ID of the space
    # + queries - Query parameters for filtering, ordering, and pagination
    # + return - A list of messages or an error
    resource isolated function get spaces/[string spaceId]/messages(
            *ListMessagesQueries queries) returns ListMessagesResponse|error {
        string path = "/spaces/" + spaceId + "/messages" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = ListMessagesResponse);
    }

    # Returns details about a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + return - The message or an error
    resource isolated function get spaces/[string spaceId]/messages/[string messageId]()
            returns Message|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId;
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = Message);
    }

    # Updates a message using PATCH. Allows updating the text, cards, and attachments.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message to update
    # + payload - The updated message fields
    # + queries - Query parameters (updateMask, allowMissing)
    # + return - The updated message or an error
    resource isolated function patch spaces/[string spaceId]/messages/[string messageId](
            UpdateMessageRequest payload,
            *UpdateMessageQueries queries) returns Message|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->patch(path, payload, headers, targetType = Message);
    }

    # Deletes a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message to delete
    # + return - An error if the operation fails
    resource isolated function delete spaces/[string spaceId]/messages/[string messageId]()
            returns error? {
        string path = "/spaces/" + spaceId + "/messages/" + messageId;
        map<string|string[]>? headers = check self.authHeaders();
        http:Response _ = check self.httpClient->delete(path, headers = headers);
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
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->post(path, payload, headers, targetType = Membership);
    }

    # Lists memberships in a space.
    #
    # + spaceId - The ID of the space
    # + queries - Query parameters for filtering and pagination
    # + return - A list of memberships or an error
    resource isolated function get spaces/[string spaceId]/members(
            *ListMembershipsQueries queries) returns ListMembershipsResponse|error {
        string path = "/spaces/" + spaceId + "/members" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = ListMembershipsResponse);
    }

    # Returns details about a membership.
    #
    # + spaceId - The ID of the space
    # + memberId - The ID of the member
    # + queries - Query parameters (optional `useAdminAccess` for admin privileges)
    # + return - The membership or an error
    resource isolated function get spaces/[string spaceId]/members/[string memberId](
            *GetMembershipQueries queries) returns Membership|error {
        string path = "/spaces/" + spaceId + "/members/" + memberId + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = Membership);
    }

    # Updates a membership (e.g., changes a member's role in a space).
    #
    # + spaceId - The ID of the space
    # + memberId - The ID of the member to update
    # + payload - The membership with updated fields
    # + queries - Query parameters (`updateMask` is required; optionally `useAdminAccess`)
    # + return - The updated membership or an error
    resource isolated function patch spaces/[string spaceId]/members/[string memberId](
            Membership payload,
            *UpdateMembershipQueries queries) returns Membership|error {
        string path = "/spaces/" + spaceId + "/members/" + memberId + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->patch(path, payload, headers, targetType = Membership);
    }

    # Deletes a membership (removes a user or Chat app from a space).
    #
    # + spaceId - The ID of the space
    # + memberId - The ID of the member to remove
    # + return - An error if the operation fails
    resource isolated function delete spaces/[string spaceId]/members/[string memberId]()
            returns error? {
        string path = "/spaces/" + spaceId + "/members/" + memberId;
        map<string|string[]>? headers = check self.authHeaders();
        http:Response _ = check self.httpClient->delete(path, headers = headers);
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
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->post(path, payload, headers, targetType = Reaction);
    }

    # Lists reactions on a message.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + queries - Query parameters for filtering and pagination
    # + return - A list of reactions or an error
    resource isolated function get spaces/[string spaceId]/messages/[string messageId]/reactions(
            *ListReactionsQueries queries) returns ListReactionsResponse|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId + "/reactions" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = ListReactionsResponse);
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
        map<string|string[]>? headers = check self.authHeaders();
        http:Response _ = check self.httpClient->delete(path, headers = headers);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Attachments
    // ═════════════════════════════════════════════════════════════════════════

    # Uploads an attachment to a Google Chat space.
    #
    # + spaceId - The ID of the space that will own the uploaded attachment
    # + payload - The attachment metadata and file bytes to upload
    # + return - The uploaded attachment reference or an error
    resource isolated function post spaces/[string spaceId]/attachments/upload(
            UploadAttachmentRequest payload) returns UploadAttachmentResponse|error {
        string path = "/spaces/" + spaceId + "/attachments:upload";

        mime:Entity metadataPart = new;
        metadataPart.setJson({filename: payload.filename});
        mime:ContentDisposition metadataContentDisposition = new;
        metadataContentDisposition.disposition = "form-data";
        metadataContentDisposition.name = "metadata";
        metadataPart.setContentDisposition(metadataContentDisposition);

        mime:Entity mediaPart = new;
        mediaPart.setByteArray(payload.mediaBytes);
        mime:ContentDisposition mediaContentDisposition = new;
        mediaContentDisposition.disposition = "form-data";
        mediaContentDisposition.name = "file";
        mediaContentDisposition.fileName = payload.filename;
        mediaPart.setContentDisposition(mediaContentDisposition);

        http:Request request = new;
        request.setBodyParts([metadataPart, mediaPart], mime:MULTIPART_RELATED);
        map<string|string[]>? headers = check self.authHeaders();
        if headers is map<string|string[]> {
            string|string[]? auth = headers["Authorization"];
            if auth is string {
                request.setHeader("Authorization", auth);
            }
        }
        return self.uploadHttpClient->post(path, request, targetType = UploadAttachmentResponse);
    }

    # Gets the metadata of a message attachment.
    #
    # + spaceId - The ID of the space
    # + messageId - The ID of the message
    # + attachmentId - The ID of the attachment
    # + return - The attachment metadata or an error
    resource isolated function get spaces/[string spaceId]/messages/[string messageId]/attachments/[string attachmentId]()
            returns Attachment|error {
        string path = "/spaces/" + spaceId + "/messages/" + messageId + "/attachments/" + attachmentId;
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = Attachment);
    }

    # Downloads attachment bytes using the media API.
    #
    # Pass the exact `attachmentDataRef.resourceName` value returned by Google Chat.
    # Treat this value as opaque and do not parse or reconstruct it.
    #
    # + resourceName - The opaque media resource name from `Attachment.attachmentDataRef.resourceName`
    # + return - The downloaded media bytes or an error
    remote isolated function downloadMedia(string resourceName) returns byte[]|error {
        string path = "/media/" + resourceName + "?alt=media";
        map<string|string[]>? headers = check self.authHeaders();
        http:Response response = check self.httpClient->get(path, headers);
        return response.getBinaryPayload();
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
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = SpaceEvent);
    }

    # Lists events from a Google Chat space.
    #
    # + spaceId - The ID of the space
    # + queries - Query parameters (filter is required for event type)
    # + return - A list of space events or an error
    resource isolated function get spaces/[string spaceId]/spaceEvents(
            *ListSpaceEventsQueries queries) returns ListSpaceEventsResponse|error {
        string path = "/spaces/" + spaceId + "/spaceEvents" + check getPathForQueryParam(queries);
        map<string|string[]>? headers = check self.authHeaders();
        return self.httpClient->get(path, headers, targetType = ListSpaceEventsResponse);
    }
}

# Builds a URL-encoded query string from the given query parameters.
#
# Absent (nil) values are skipped. String values are percent-encoded; other
# scalar values are stringified as-is. Returns an empty string when no
# parameters are present, otherwise a string beginning with `?`.
#
# + queryParam - The query parameters, keyed by their API query name
# + return - The encoded query string (possibly empty), or an error if encoding fails
isolated function getPathForQueryParam(map<anydata> queryParam) returns string|error {
    string[] params = [];
    foreach [string, anydata] [key, value] in queryParam.entries() {
        if value is () {
            continue;
        }
        string encodedValue = value is string ? check url:encode(value, "UTF-8") : value.toString();
        params.push(key, "=", encodedValue, "&");
    }
    if params.length() == 0 {
        return "";
    }
    _ = params.pop();
    return "?" + string:'join("", ...params);
}

isolated function resolveUploadServiceUrl(string serviceUrl) returns string {
    if serviceUrl.endsWith("/v1") {
        return serviceUrl.substring(0, serviceUrl.length() - 3) + "/upload/v1";
    }
    return CHAT_UPLOAD_API_BASE_URL;
}
