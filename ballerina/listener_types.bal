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
// Listener Configuration
// ═══════════════════════════════════════════════════════════════════════════════

# Configuration for the Google Chat trigger listener.
#
# The listener receives interaction events directly from Google Chat over HTTP.
# The `auth` credentials are used to create the internal Chat API client
# (for responding to events via the Chat API).
#
# **For service account auth**: You can use one of three forms:
# - `ServiceAccountConfig` with `issuer` plus a PEM/private-key config
# - `ServiceAccountCredentials` with the service account represented as a Ballerina record
# - `ServiceAccountFileConfig` with the path to the JSON key file
#
# **For OAuth2 auth**: Create OAuth2 credentials in Google Cloud Console and
# obtain a refresh token with the `https://www.googleapis.com/auth/chat.bot` scope.
#
# **For bearer token auth**: Provide a pre-obtained OAuth2 access token.
# Note that Google access tokens expire after ~1 hour; if the listener runs
# longer, the Chat API client may fail.
#
# + auth - Authentication for the Chat API client
#           (service account, OAuth2, or bearer token)
# + httpListenerConfig - Optional inbound HTTP listener settings
@display {label: "Listener Config"}
public type ListenerConfig record {|
    @display {label: "Auth Config"}
    ServiceAccountAuthConfig|OAuth2Config|http:BearerTokenConfig auth;
    @display {label: "HTTP Listener Config"}
    http:ListenerConfiguration httpListenerConfig = {};
|};

// ═══════════════════════════════════════════════════════════════════════════════
// Service Annotation
// ═══════════════════════════════════════════════════════════════════════════════

# HTTP mode configuration that verifies bearer tokens using the HTTP endpoint URL
# as the audience (Google's recommended approach).
#
# Use this when your Chat app configuration in Google Cloud Console has
# **Authentication Audience** set to **HTTP endpoint URL**. Google Chat will
# send a Google-signed OIDC ID token whose `aud` claim matches the endpoint URL.
#
# + endpointUrl - The public HTTPS URL of this listener, exactly as entered in
#                 the **HTTP endpoint URL** field of the Chat app configuration
#                 (e.g., `"https://my-app.example.com"`). The listener validates
#                 the `aud` claim of every incoming bearer token against this value.
@display {label: "HTTP Endpoint URL Config"}
public type HttpEndpointUrlConfig record {|
    @display {label: "Endpoint URL"}
    string endpointUrl;
|};

# HTTP mode configuration that verifies bearer tokens using the GCP project
# number as the audience.
#
# Use this when your Chat app configuration in Google Cloud Console has
# **Authentication Audience** set to **Project Number**. Google Chat will send
# a self-signed JWT whose `aud` claim matches the GCP project number.
#
# + projectNumber - The GCP project number used to build the Chat app, as a
#                   string (e.g., `"1234567890"`). The listener validates the
#                   `aud` claim of every incoming bearer token against this value.
@display {label: "Project Number Config"}
public type ProjectNumberConfig record {|
    @display {label: "Project Number"}
    string projectNumber;
|};

# HTTP-based configuration for the Google Chat trigger.
#
# A union of the two supported bearer token verification approaches:
#
# - `HttpEndpointUrlConfig` (recommended): bearer token is a Google-signed OIDC
#   ID token; audience is your HTTP endpoint URL.
# - `ProjectNumberConfig`: bearer token is a self-signed JWT; audience is your
#   GCP project number.
#
# Choose the variant that matches the **Authentication Audience** setting in your
# Chat app configuration in Google Cloud Console.
public type HttpConfig HttpEndpointUrlConfig|ProjectNumberConfig;

# Service-level configuration for the Google Chat trigger.
#
# Apply one of the supported HTTP configurations to the `@chat:ServiceConfig`
# annotation on your `chat:ChatService`.
#
# **HTTP mode — endpoint URL verification** (recommended):
# ```ballerina
# @chat:ServiceConfig {
#     endpointUrl: "https://my-app.example.com"
# }
# service chat:ChatService on chatListener { ... }
# ```
#
# **HTTP mode — project number verification:**
# ```ballerina
# @chat:ServiceConfig {
#     projectNumber: "1234567890"
# }
# service chat:ChatService on chatListener { ... }
# ```
public type ServiceConfiguration HttpConfig;

# Annotation for service-level Google Chat trigger configuration.
public annotation ServiceConfiguration ServiceConfig on service;

// ═══════════════════════════════════════════════════════════════════════════════
// Chat Interaction Event
// ═══════════════════════════════════════════════════════════════════════════════

# A Google Chat app interaction event.
#
# This represents the full event payload that Google Chat sends when a user
# interacts with the Chat app. The `type` field determines which remote function
# on the `ChatService` is invoked.
#
# + type - The type of interaction event
# + eventTime - When the event occurred (RFC 3339 timestamp)
# + token - A secret value for legacy verification (modern apps should not rely on this)
# + threadKey - The Chat app-defined key for the thread related to this event
# + message - The message that triggered the event (for MESSAGE, ADDED_TO_SPACE, CARD_CLICKED)
# + user - The user that triggered the interaction
# + thread - The thread related to the event
# + space - The space where the interaction occurred
# + action - The form action data (for CARD_CLICKED and SUBMIT_FORM events)
# + configCompleteRedirectUrl - URL to redirect after configuration completes (for MESSAGE, ADDED_TO_SPACE, APP_COMMAND)
# + isDialogEvent - Whether this is a dialog-related event (for CARD_CLICKED and MESSAGE)
# + dialogEventType - The type of dialog event
# + common - Information about the user's client (locale, platform, form inputs)
# + appCommandMetadata - Metadata about a Chat app command (for APP_COMMAND events)
public type ChatEvent record {
    EventType 'type;
    string eventTime?;
    string token?;
    string threadKey?;
    Message message?;
    User user?;
    ChatThread thread?;
    Space space?;
    FormAction action?;
    string configCompleteRedirectUrl?;
    boolean isDialogEvent?;
    DialogEventType dialogEventType?;
    CommonEventObject common?;
    AppCommandMetadata appCommandMetadata?;
};

# A Google Chat message interaction event with a guaranteed non-optional `message` field.
#
# Use this instead of `ChatEvent` as the parameter type for `onMessage` when you want
# compile-time assurance that `message` is present, avoiding nil-check operators on access.
#
# **Example:**
# ```ballerina
# remote function onMessage(chat:MessageEvent event, chat:MessageCaller caller) returns error? {
#     string text = event.message.text ?: "(no text)";  // no ?. needed on .message
# }
# ```
#
# + message - The message that triggered the event (always present for MESSAGE events)
public type MessageEvent record {
    *ChatEvent;
    Message message;
};

// ═══════════════════════════════════════════════════════════════════════════════
// Chat Service Interface
// ═══════════════════════════════════════════════════════════════════════════════

# Triggers when a Google Chat interaction event is received.
#
# Implement this service object to handle Chat app events. Each remote function
# corresponds to a specific event type. You only need to implement the handlers
# relevant to your Chat app.
#
# Each handler receives the event and an event-specific Caller for responding.
# The Caller's respond() method sends a synchronous HTTP response back to
# Google Chat. Additional async Chat API operations (sendMessage, updateMessage,
# etc.) are available on callers that support them.
#
# ```ballerina
# remote function onMessage(chat:MessageEvent event, chat:MessageCaller caller) returns error? {
#     check caller->respond({ text: "Got your message!" });
# }
#
# remote function onAppHome(chat:ChatEvent event, chat:AppHomeCaller caller) returns error? {
#     check caller->respond({ sections: [{ widgets: [{ textParagraph: { text: "Welcome!" } }] }] });
# }
# ```
#
# **Available event handlers:**
# - `onMessage(MessageEvent|ChatEvent, MessageCaller)` - A user sends a message
# - `onAddedToSpace(ChatEvent, MessageCaller)` - The app is added to a space
# - `onRemovedFromSpace(ChatEvent)` - The app is removed from a space (no caller)
# - `onCardClicked(ChatEvent, CardClickedCaller)` - A user clicks a button/card element
# - `onWidgetUpdated(ChatEvent, WidgetUpdatedCaller)` - A user updates a widget
# - `onAppCommand(ChatEvent, MessageCaller)` - A user invokes a command
# - `onAppHome(ChatEvent, AppHomeCaller)` - A user navigates to the app home
# - `onSubmitForm(ChatEvent, SubmitFormCaller)` - A user submits a form from app home
public type ChatService distinct service object {
    // The service type is kept minimal. The native Java dispatcher inspects
    // the actual remote function signatures at runtime to determine which
    // event-specific Caller to inject alongside the ChatEvent.
};

# Union type for all service types the listener can attach.
public type GenericServiceType ChatService;


