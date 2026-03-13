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
# The listener supports two delivery modes, selected via the `@ServiceConfig`
# annotation on the attached service:
#
# - **Pub/Sub mode** (`PubSubConfig`): The listener auto-creates a push
#   subscription on a pre-existing topic, receives events via webhook push,
#   and deletes the subscription on shutdown.
# - **HTTP mode** (`HttpEndpointUrlConfig` or `ProjectNumberConfig`): The
#   listener receives interaction events directly from Google Chat over HTTP.
#   No Pub/Sub resources are managed.
#
# In both modes the `auth` credentials are used to create the internal
# `Caller` client (for responding to events via the Chat API). In Pub/Sub mode
# the same credentials are also used for Pub/Sub subscription management.
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
# longer, the `Caller` and (in Pub/Sub mode) the subscription cleanup call on
# `Listener.gracefulStop()` may fail.
#
# + auth - Authentication for the Chat API client and (in Pub/Sub mode) for
#           Pub/Sub subscription management (service account, OAuth2, or bearer token)
# + secureSocketConfig - Optional SSL/TLS configuration for the HTTP listener
@display {label: "Listener Config"}
public type ListenerConfig record {
    @display {label: "Auth Config"}
    ServiceAccountAuthConfig|OAuth2Config|http:BearerTokenConfig auth;
    @display {label: "SSL Config"}
    http:ClientSecureSocket secureSocketConfig?;
};

// ═══════════════════════════════════════════════════════════════════════════════
// Service Annotation
// ═══════════════════════════════════════════════════════════════════════════════

# Pub/Sub-based configuration for the Google Chat trigger.
#
# Use this when your Chat app receives events via Google Cloud Pub/Sub push
# subscriptions (e.g., when running behind a firewall or subscribing to
# Google Workspace Events). The listener automatically creates a push
# subscription on the given topic and deletes it on shutdown.
#
# The topic must already exist and be configured as the connection target
# in the Google Chat API configuration page in Google Cloud Console.
#
# + topicName - Fully qualified Pub/Sub topic resource name that the Chat app
#               is configured to publish to. Format:
#               `projects/<project-id>/topics/<topic-name>`.
# + callbackURL - The public URL where Pub/Sub will push events. In development,
#                 use a tunnel like ngrok (e.g., `https://abc.ngrok.io/webhook`).
#                 In production, use your deployed service URL.
@display {label: "Pub/Sub Config"}
public type PubSubConfig record {|
    @display {label: "Pub/Sub Topic Name"}
    string topicName;
    @display {label: "Callback URL"}
    string callbackURL;
|};

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
# A union of the three supported delivery configurations. Apply one to the
# `@chat:ServiceConfig` annotation on your `chat:ChatService`.
#
# **Pub/Sub mode** — events arrive via Google Cloud Pub/Sub push:
# ```ballerina
# @chat:ServiceConfig {
#     topicName: "projects/my-project/topics/my-chat-topic",
#     callbackURL: "https://my-app.example.com/webhook"
# }
# service chat:ChatService on chatListener { ... }
# ```
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
public type ServiceConfiguration PubSubConfig|HttpConfig;

# Annotation for service-level Google Chat trigger configuration.
public annotation ServiceConfiguration ServiceConfig on service;

// ═══════════════════════════════════════════════════════════════════════════════
// Chat Interaction Event (Pub/Sub Payload)
// ═══════════════════════════════════════════════════════════════════════════════

# A Google Chat app interaction event received via Pub/Sub push.
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

// ═══════════════════════════════════════════════════════════════════════════════
// Chat Service Interface
// ═══════════════════════════════════════════════════════════════════════════════

# Triggers when a Google Chat interaction event is received.
#
# Implement this service object to handle Chat app events. Each remote function
# corresponds to a specific event type. You only need to implement the handlers
# relevant to your Chat app.
#
# Each handler can accept just the event, or both the event and a `Caller`:
# ```ballerina
# // Without Caller (event-only)
# remote function onMessage(googlechat:ChatEvent event) returns error? { ... }
#
# // With Caller (enables bot-safe message and space operations)
# remote function onMessage(googlechat:ChatEvent event, googlechat:Caller caller) returns error? {
#     googlechat:Message message = check caller->reply("Hello!");
#     check caller->deleteMessage(message);
# }
# ```
#
# **Available event handlers:**
# - `onMessage` - A user sends a message (DM, @mention, slash command)
# - `onAddedToSpace` - The app is added to a space
# - `onRemovedFromSpace` - The app is removed from a space
# - `onCardClicked` - A user clicks a button/card element
# - `onWidgetUpdated` - A user updates a widget in a card or dialog
# - `onAppCommand` - A user invokes a slash or quick command
# - `onAppHome` - A user navigates to the app home
# - `onSubmitForm` - A user submits a form/dialog
public type ChatService distinct service object {
    // The service type is kept minimal. The native Java dispatcher inspects
    // the actual remote function signatures at runtime to determine whether
    // to inject a Caller parameter alongside the ChatEvent.
};

# Union type for all service types the listener can attach.
public type GenericServiceType ChatService;

// ═══════════════════════════════════════════════════════════════════════════════
// Pub/Sub Internal Types
// ═══════════════════════════════════════════════════════════════════════════════

# Holds the resource name of the Pub/Sub subscription created by the listener.
#
# + subscriptionResource - Fully qualified subscription resource name
type SubscriptionDetail record {
    string subscriptionResource;
};

# Represents a Pub/Sub subscription request.
#
# + pushEndpoint - URL where messages should be pushed
# + attributes - Endpoint configuration attributes
# + oidcToken - OIDC token for authenticating push requests
type PushConfig record {
    string pushEndpoint;
    map<string> attributes?;
    OidcToken oidcToken?;
};

# OIDC token configuration for Pub/Sub push authentication.
#
# + serviceAccountEmail - Service account email for generating the token
# + audience - Audience claim for the token
type OidcToken record {
    string serviceAccountEmail;
    string audience;
};

# Represents a Pub/Sub subscription request.
#
# + topic - The topic to subscribe to
# + pushConfig - Push delivery configuration
# + ackDeadlineSeconds - Acknowledgment deadline in seconds
type SubscriptionRequest record {
    string topic;
    PushConfig pushConfig;
    int ackDeadlineSeconds?;
};

# Represents a Pub/Sub subscription resource.
#
# + name - Fully qualified name of the subscription
type Subscription record {
    string name;
    *SubscriptionRequest;
};
