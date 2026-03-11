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
# The listener creates a Pub/Sub push subscription on a pre-existing topic and
# receives Google Chat interaction events via webhook push delivery. The topic
# must already exist and be configured in the Google Chat app connection settings
# in Google Cloud Console.
#
# **For service account auth**: You can use one of three forms:
# - `ServiceAccountConfig` with `issuer` plus a PEM/private-key config
# - `ServiceAccountCredentials` with the service account represented as a Ballerina record
# - `ServiceAccountFileConfig` with the path to the JSON key file
#
# **For OAuth2 auth**: Create OAuth2 credentials in Google Cloud Console and
# obtain a refresh token with the `https://www.googleapis.com/auth/pubsub` scope.
#
# **For bearer token auth**: Provide a pre-obtained OAuth2 access token with the
# `https://www.googleapis.com/auth/pubsub` scope. Note that Google access tokens
# expire after ~1 hour; if the listener runs longer than that, the subscription
# cleanup call on `Listener.gracefulStop()` may fail (the subscription will be orphaned,
# same as a hard exit).
#
# + auth - Authentication for Pub/Sub subscription management (service account,
#           OAuth2 with auto-refresh, or a pre-obtained bearer token)
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

# Service-level configuration for the Google Chat trigger.
#
# Apply this annotation to the `chat:ChatService` to specify the Pub/Sub topic
# and the public callback URL that Pub/Sub will push events to.
#
# + topicName - Fully qualified Pub/Sub topic resource name that the Chat app
#               is configured to publish to. Format:
#               `projects/<project-id>/topics/<topic-name>`.
#               Create this topic once in Google Cloud Console and configure
#               it in the Chat app connection settings.
# + callbackURL - The public URL where Pub/Sub will push events to this listener.
#                 In development, use a tunnel like ngrok (e.g., `https://abc.ngrok.io/webhook`).
#                 In production, use your deployed service URL.
public type ServiceConfiguration record {|
    @display {label: "Pub/Sub Topic Name"}
    string topicName;
    @display {label: "Callback URL"}
    string callbackURL;
|};

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
# + configCompleteRedirectUrl - URL to redirect after configuration completes
# + isDialogEvent - Whether this is a dialog-related event
# + dialogEventType - The type of dialog event
# + common - Information about the user's client (locale, platform, form inputs)
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
# // With Caller (enables bot-safe reply operations)
# remote function onMessage(googlechat:ChatEvent event, googlechat:Caller caller) returns error? {
#     check caller->reply("Hello!");
# }
# ```
#
# **Available event handlers:**
# - `onMessage` - A user sends a message (DM, @mention, slash command)
# - `onAddedToSpace` - The app is added to a space
# - `onRemovedFromSpace` - The app is removed from a space
# - `onCardClicked` - A user clicks a button/card element
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
