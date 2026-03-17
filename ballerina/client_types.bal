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

// ═══════════════════════════════════════════════════════════════════════════════
// Client Authentication Types
// ═══════════════════════════════════════════════════════════════════════════════

# Google service account credentials for JWT-based authentication.
# Maps to the service account JSON key file downloaded from
# Google Cloud Console > IAM & Admin > Service Accounts.
#
# The library internally constructs a JWT assertion using these fields and
# exchanges it for an OAuth2 access token via the JWT Bearer Grant (RFC 7523).
# You do **not** need to set audience, scopes, or expiry — those are handled
# automatically.
#
# **Field mapping from service account JSON:**
# - `issuer` -> `client_email`
# - `signatureConfig.config.keyFile` -> save `private_key` as a `.pem` file
#
# **Example:**
# ```ballerina
# chat:ServiceAccountConfig saConfig = {
#     issuer: "my-bot@my-project.iam.gserviceaccount.com",
#     signatureConfig: {
#         config: { keyFile: "/path/to/private-key.pem" }
#     }
# };
# ```
#
# + issuer - Service account email address (`client_email` from the JSON key file)
# + signatureConfig - RSA signature configuration pointing to the PEM private key file
@display {label: "Service Account Config"}
public type ServiceAccountConfig record {|
    @display {label: "Issuer (Service Account Email)"}
    string issuer;
    @display {label: "Signature Config"}
    jwt:IssuerSignatureConfig signatureConfig;
|};

# Google service account credentials represented directly as a Ballerina record.
# This mirrors the common fields in the service account JSON key file downloaded
# from Google Cloud Console > IAM & Admin > Service Accounts.
#
# The library validates that the account `type` is `service_account`, then uses
# `client_email` and `private_key` to construct the JWT bearer grant internally.
#
# **Example:**
# ```ballerina
# chat:ServiceAccountCredentials saCredentials = {
#     client_email: "my-bot@my-project.iam.gserviceaccount.com",
#     private_key: string `-----BEGIN PRIVATE KEY-----
# ...
# -----END PRIVATE KEY-----`
# };
# ```
#
# + type - Google credential type. Must be `service_account`
# + project_id - Google Cloud project ID
# + private_key_id - Private key ID from the service account JSON
# + private_key - PEM-encoded private key content from the service account JSON
# + client_email - Service account email address
# + client_id - Numeric client ID
# + auth_uri - Google OAuth authorization URI
# + token_uri - Google OAuth token URI
# + auth_provider_x509_cert_url - Google auth provider certificate URL
# + client_x509_cert_url - Service account certificate URL
# + universe_domain - Google API universe domain
@display {label: "Service Account Credentials"}
public type ServiceAccountCredentials record {|
    @display {label: "Type"}
    string 'type = "service_account";
    @display {label: "Project ID"}
    string project_id?;
    @display {label: "Private Key ID"}
    string private_key_id?;
    @display {label: "Private Key"}
    string private_key;
    @display {label: "Client Email"}
    string client_email;
    @display {label: "Client ID"}
    string client_id?;
    @display {label: "Auth URI"}
    string auth_uri?;
    @display {label: "Token URI"}
    string token_uri?;
    @display {label: "Auth Provider Cert URL"}
    string auth_provider_x509_cert_url?;
    @display {label: "Client Cert URL"}
    string client_x509_cert_url?;
    @display {label: "Universe Domain"}
    string universe_domain?;
|};

# Path to a Google service account JSON key file.
#
# The library reads the JSON file, validates it as a service account credential,
# and constructs the JWT bearer grant internally.
#
# + path - Path to the Google service account JSON key file
@display {label: "Service Account File Config"}
public type ServiceAccountFileConfig record {|
    @display {label: "Service Account File Path"}
    string path;
|};

# Supported service-account-based authentication inputs.
public type ServiceAccountAuthConfig ServiceAccountConfig|ServiceAccountCredentials|ServiceAccountFileConfig;

# OAuth2 credentials for user-authenticated access. Obtain from
# Google Cloud Console > APIs & Credentials > OAuth 2.0 Client IDs, then use the
# OAuth2 Playground or consent flow to get a refresh token with the
# `https://www.googleapis.com/auth/chat.bot` scope.
#
# + clientId - OAuth2 Client ID
# + clientSecret - OAuth2 Client Secret
# + refreshUrl - Token refresh endpoint. Defaults to Google's OAuth2 token URL
# + refreshToken - OAuth2 refresh token with the required scope
@display {label: "OAuth2 Config"}
public type OAuth2Config record {|
    @display {label: "Client ID"}
    string clientId;
    @display {label: "Client Secret"}
    string clientSecret;
    @display {label: "Refresh URL"}
    string refreshUrl = GOOGLE_TOKEN_URL;
    @display {label: "Refresh Token"}
    string refreshToken;
|};

// ═══════════════════════════════════════════════════════════════════════════════
// Client Connection Config
// ═══════════════════════════════════════════════════════════════════════════════

# Configuration for the Google Chat API client. Supports three authentication modes:
#
# 1. **Service Account PEM** (`ServiceAccountConfig`): Service account email plus a PEM/private-key configuration.
# 2. **Service Account Record** (`ServiceAccountCredentials`): Inline Ballerina record matching the Google JSON key file.
# 3. **Service Account File** (`ServiceAccountFileConfig`): Path to the Google JSON key file.
# 4. **OAuth2** (`OAuth2Config`): For user-authenticated access with automatic token refresh.
# 5. **Bearer Token** (`http:BearerTokenConfig`): For short-lived pre-obtained tokens.
#
# + auth - Authentication configuration (service account, OAuth2, or bearer token)
# + httpVersion - The HTTP version to use. Defaults to HTTP/2
# + http1Settings - HTTP/1.x protocol settings
# + http2Settings - HTTP/2 protocol settings
# + timeout - Maximum time (in seconds) to wait for a response. Defaults to 30s
# + forwarded - The `forwarded`/`x-forwarded` header setting
# + followRedirects - Redirect handling configuration
# + poolConfig - Connection pool configuration
# + cache - HTTP caching configuration
# + compression - Compression handling for `accept-encoding` header
# + circuitBreaker - Circuit breaker configuration
# + retryConfig - Retry configuration
# + cookieConfig - Cookie handling configuration
# + responseLimits - Inbound response size limits
# + secureSocket - SSL/TLS configuration
# + proxy - Proxy server configuration
# + socketConfig - Client socket configuration
# + validation - Enable/disable constraint validation. Defaults to true
# + laxDataBinding - Enable relaxed data binding (nil-safe). Defaults to true
@display {label: "Connection Config"}
public type ConnectionConfig record {|
    @display {label: "Auth Config"}
    ServiceAccountAuthConfig|OAuth2Config|http:BearerTokenConfig auth;
    http:HttpVersion httpVersion = http:HTTP_2_0;
    http:ClientHttp1Settings http1Settings = {};
    http:ClientHttp2Settings http2Settings = {};
    decimal timeout = 30;
    string forwarded = "disable";
    http:FollowRedirects followRedirects?;
    http:PoolConfiguration poolConfig?;
    http:CacheConfig cache = {};
    http:Compression compression = http:COMPRESSION_AUTO;
    http:CircuitBreakerConfig circuitBreaker?;
    http:RetryConfig retryConfig?;
    http:CookieConfig cookieConfig?;
    http:ResponseLimitConfigs responseLimits = {};
    http:ClientSecureSocket secureSocket?;
    http:ProxyConfig proxy?;
    http:ClientSocketConfig socketConfig = {};
    boolean validation = true;
    boolean laxDataBinding = true;
|};

// ═══════════════════════════════════════════════════════════════════════════════
// Query Parameter Records for Client API Operations
// ═══════════════════════════════════════════════════════════════════════════════

# Query parameters for listing spaces.
#
# + pageSize - Maximum number of spaces to return (max 1000)
# + pageToken - Page token from a previous list request
# + filter - A query filter (e.g., `spaceType = "SPACE"`)
public type ListSpacesQueries record {
    int pageSize?;
    string pageToken?;
    string filter?;
};

# Query parameters for creating a message.
#
# + threadKey - Thread identifier for creating or replying to a thread
# + requestId - A unique request ID for idempotent requests
# + messageReplyOption - How to handle threading when `threadKey` is set
# + messageId - A custom ID for the message
public type CreateMessageQueries record {
    string threadKey?;
    string requestId?;
    string messageReplyOption?;
    string messageId?;
};

# Query parameters for listing messages.
#
# + pageSize - Maximum number of messages to return (max 1000)
# + pageToken - Page token from a previous list request
# + filter - A query filter
# + orderBy - Ordering of results (e.g., `createTime desc`)
# + showDeleted - Whether to include deleted messages in the response
public type ListMessagesQueries record {
    int pageSize?;
    string pageToken?;
    string filter?;
    string orderBy?;
    boolean showDeleted?;
};

# Query parameters for updating a message.
#
# + updateMask - The field paths to update (comma-separated)
# + allowMissing - If true, create the message if it doesn't exist
public type UpdateMessageQueries record {
    string updateMask = "text";
    boolean allowMissing?;
};

# Query parameters for listing memberships.
#
# + pageSize - Maximum number of memberships to return (max 1000)
# + pageToken - Page token from a previous list request
# + filter - A query filter (e.g., `role = "ROLE_MANAGER"`)
# + showGroups - Whether to include Google Group memberships
# + showInvited - Whether to include invited memberships
# + useAdminAccess - Whether to use admin access for the request
public type ListMembershipsQueries record {
    int pageSize?;
    string pageToken?;
    string filter?;
    boolean showGroups?;
    boolean showInvited?;
    boolean useAdminAccess?;
};

# Query parameters for listing reactions.
#
# + pageSize - Maximum number of reactions to return (max 25)
# + pageToken - Page token from a previous list request
# + filter - A query filter (e.g., filter by emoji)
public type ListReactionsQueries record {
    int pageSize?;
    string pageToken?;
    string filter?;
};

# Query parameters for updating a space.
#
# + updateMask - The field paths to update (comma-separated)
public type UpdateSpaceQueries record {
    string updateMask?;
};

# Query parameters for finding a direct message space with a user.
#
# + name - Resource name of the user to find DM with. Format: `users/{user}`
public type FindDirectMessageQueries record {
    string name?;
};

# Query parameters for listing space events.
#
# + pageSize - Maximum number of events to return
# + pageToken - Page token from a previous list request
# + filter - Required. An event type filter (e.g., `eventTypes:"google.workspace.chat.message.v1.created"`)
public type ListSpaceEventsQueries record {
    int pageSize?;
    string pageToken?;
    string filter;
};

# Query parameters for searching spaces (admin access required).
#
# Requires user authentication with administrator privileges and the
# `chat.admin.spaces` or `chat.admin.spaces.readonly` OAuth scope.
#
# + query - Required. A search query supporting fields such as `createTime`, `customer`,
#           `displayName`, `externalUserAllowed`, `lastActiveTime`, `spaceHistoryState`,
#           and `spaceType`. `customer` and `spaceType` are required fields in the query.
#           Example: `customer = "customers/my_customer" AND spaceType = "SPACE"`
# + useAdminAccess - Must be `true`. Runs the method using the user's Google Workspace
#                    administrator privileges
# + pageSize - Maximum number of spaces to return (default 100, max 1000)
# + pageToken - Page token from a previous search request for pagination
# + orderBy - How to order the results. Supported values: `membershipCount.joined_direct_human_user_count`,
#             `lastActiveTime`, `createTime`. Append `ASC` or `DESC` (e.g., `lastActiveTime DESC`)
public type SearchSpacesQueries record {
    string query;
    boolean useAdminAccess?;
    int pageSize?;
    string pageToken?;
    string orderBy?;
};

# Request body for setting up a space with initial members.
#
# Creates a space and adds specified users or Google Groups to it. The calling
# user is automatically added and should not be specified in `memberships`.
#
# Requires user authentication with the `chat.spaces` or `chat.spaces.create`
# OAuth scope.
#
# + space - Required. The space to create. `Space.spaceType` is required.
#           Set `spaceType` to `SPACE` for a named space, `GROUP_CHAT` for a group
#           chat, or `DIRECT_MESSAGE` for a 1:1 DM
# + requestId - Optional unique identifier for idempotency. A random UUID is recommended.
#               Re-using an existing ID returns the previously created space
# + memberships - Optional list of human users or Google Groups to invite. The calling
#                 user is added automatically. Maximum 49 memberships
public type SetUpSpaceRequest record {
    Space space;
    string requestId?;
    Membership[] memberships?;
};
