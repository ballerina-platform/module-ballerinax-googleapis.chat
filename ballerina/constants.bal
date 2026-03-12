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

// ── API Base URLs ───────────────────────────────────────────────────────────────

# Base URL for the Google Chat REST API v1.
const string CHAT_API_BASE_URL = "https://chat.googleapis.com/v1";

# Base URL for the Google Cloud Pub/Sub API v1.
const string PUBSUB_BASE_URL = "https://pubsub.googleapis.com/v1/";

# Google OAuth2 token endpoint.
const string GOOGLE_TOKEN_URL = "https://accounts.google.com/o/oauth2/token";

# Google OAuth2 token endpoint for JWT Bearer Grant (service account flow).
const string GOOGLE_OAUTH2_TOKEN_URL = "https://oauth2.googleapis.com/token";

// ── Pub/Sub Resource Paths ──────────────────────────────────────────────────────

# Resource path prefix for Google Cloud projects.
const string PROJECTS = "projects/";

# Resource path segment for Pub/Sub subscriptions.
const string SUBSCRIPTIONS = "/subscriptions/";

// ── Pub/Sub Naming ──────────────────────────────────────────────────────────────

# Prefix for auto-generated Pub/Sub subscription names.
const string SUBSCRIPTION_NAME_PREFIX = "chat-sub-";

// ── Symbols ─────────────────────────────────────────────────────────────────────

const string FORWARD_SLASH = "/";
const string EMPTY_STRING = "";

// ── Scopes ──────────────────────────────────────────────────────────────────────

# OAuth2 scope for Pub/Sub access.
const string PUBSUB_SCOPE = "https://www.googleapis.com/auth/pubsub";

# OAuth2 scope for Chat bot access (service account).
const string CHAT_BOT_SCOPE = "https://www.googleapis.com/auth/chat.bot";

# OAuth2 scope for managing Chat messages (user auth).
const string CHAT_MESSAGES_SCOPE = "https://www.googleapis.com/auth/chat.messages";

# OAuth2 scope for creating Chat messages (user auth).
const string CHAT_MESSAGES_CREATE_SCOPE = "https://www.googleapis.com/auth/chat.messages.create";

# OAuth2 scope for reading Chat messages (user auth).
const string CHAT_MESSAGES_READONLY_SCOPE = "https://www.googleapis.com/auth/chat.messages.readonly";

# OAuth2 scope for managing Chat spaces (user auth).
const string CHAT_SPACES_SCOPE = "https://www.googleapis.com/auth/chat.spaces";

# OAuth2 scope for reading Chat spaces (user auth).
const string CHAT_SPACES_READONLY_SCOPE = "https://www.googleapis.com/auth/chat.spaces.readonly";

# OAuth2 scope for managing Chat memberships (user auth).
const string CHAT_MEMBERSHIPS_SCOPE = "https://www.googleapis.com/auth/chat.memberships";

# OAuth2 scope for reading Chat memberships (user auth).
const string CHAT_MEMBERSHIPS_READONLY_SCOPE = "https://www.googleapis.com/auth/chat.memberships.readonly";

// ── Event Type Constants ────────────────────────────────────────────────────────

# Event type string for a message event.
const string EVENT_TYPE_MESSAGE = "MESSAGE";

# Event type string for an added-to-space event.
const string EVENT_TYPE_ADDED_TO_SPACE = "ADDED_TO_SPACE";

# Event type string for a removed-from-space event.
const string EVENT_TYPE_REMOVED_FROM_SPACE = "REMOVED_FROM_SPACE";

# Event type string for a card-clicked event.
const string EVENT_TYPE_CARD_CLICKED = "CARD_CLICKED";

# Event type string for an app-home event.
const string EVENT_TYPE_APP_HOME = "APP_HOME";

# Event type string for a submit-form event.
const string EVENT_TYPE_SUBMIT_FORM = "SUBMIT_FORM";

// ── Log Messages ────────────────────────────────────────────────────────────────

const string LOG_PUBSUB_SUB_CREATED = "Pub/Sub subscription created: ";
const string LOG_EVENT_RECEIVED = "Chat event received: ";
const string LOG_EVENT_DECODED = "Chat event decoded: ";
const string LOG_EVENT_DISPATCHED = "Chat event dispatched: ";

// ── Warning Messages ────────────────────────────────────────────────────────────

const string WARN_UNKNOWN_SUBSCRIPTION = "Received push notification from unknown subscription: ";
const string WARN_UNKNOWN_EVENT_TYPE = "Received unknown event type: ";

// ── Error Messages ──────────────────────────────────────────────────────────────

const string ERR_SUBSCRIPTION_CREATION = "Failed to create Pub/Sub subscription.";
const string ERR_EVENT_DISPATCH = "Failed to dispatch Chat event.";
const string ERR_PAYLOAD_PARSE = "Failed to parse Pub/Sub message payload.";
const string ERR_SERVICE_ATTACH = "Service has already been attached.";
const string ERR_SERVICE_DETACH = "Cannot detach service. Service has not been attached.";
