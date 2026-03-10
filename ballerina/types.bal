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

// ═══════════════════════════════════════════════════════════════════════════════
// Google Chat API v1 – Resource Types
// Reference: https://developers.google.com/workspace/chat/api/reference/rest
// ═══════════════════════════════════════════════════════════════════════════════

// ── Enums ───────────────────────────────────────────────────────────────────────

# The type of a Google Chat space.
public enum SpaceType {
    SPACE_TYPE_UNSPECIFIED,
    SPACE,
    GROUP_CHAT,
    DIRECT_MESSAGE
}

# Threading state of a space.
public enum SpaceThreadingState {
    SPACE_THREADING_STATE_UNSPECIFIED,
    THREADED_MESSAGES,
    GROUPED_MESSAGES,
    UNTHREADED_MESSAGES
}

# Message history state of a space.
public enum HistoryState {
    HISTORY_STATE_UNSPECIFIED,
    HISTORY_OFF,
    HISTORY_ON
}

# The type of a Chat user.
public enum UserType {
    USER_TYPE_UNSPECIFIED,
    HUMAN,
    BOT
}

# Membership state in a space.
public enum MembershipState {
    MEMBERSHIP_STATE_UNSPECIFIED,
    JOINED,
    INVITED,
    NOT_A_MEMBER
}

# Role of a member in a space.
public enum MembershipRole {
    MEMBERSHIP_ROLE_UNSPECIFIED,
    ROLE_MEMBER,
    ROLE_MANAGER
}

# Type of an annotation in a message.
public enum AnnotationType {
    ANNOTATION_TYPE_UNSPECIFIED,
    USER_MENTION,
    SLASH_COMMAND,
    RICH_LINK
}

# Type of a rich link.
public enum RichLinkType {
    RICH_LINK_TYPE_UNSPECIFIED,
    DRIVE_FILE,
    CHAT_SPACE,
    GMAIL_MESSAGE
}

# Type of an action response from a Chat app.
public enum ResponseType {
    TYPE_UNSPECIFIED,
    NEW_MESSAGE,
    UPDATE_MESSAGE,
    UPDATE_USER_MESSAGE_CARDS,
    REQUEST_CONFIG,
    DIALOG
}

# Type of deletion for a message.
public enum DeletionType {
    DELETION_TYPE_UNSPECIFIED,
    CREATOR,
    SPACE_OWNER,
    ADMIN,
    APP_MESSAGE_EXPIRY,
    CREATOR_VIA_APP,
    SPACE_OWNER_VIA_APP
}

# Access state of a space.
public enum AccessState {
    ACCESS_STATE_UNSPECIFIED,
    PRIVATE,
    DISCOVERABLE
}

# Type of dialog event.
public enum DialogEventType {
    DIALOG_EVENT_TYPE_UNSPECIFIED,
    REQUEST_DIALOG,
    SUBMIT_DIALOG,
    CANCEL_DIALOG
}

# Type of Chat app interaction event.
public enum EventType {
    EVENT_TYPE_UNSPECIFIED,
    MESSAGE,
    ADDED_TO_SPACE,
    REMOVED_FROM_SPACE,
    CARD_CLICKED,
    APP_HOME,
    SUBMIT_FORM
}

// ── Space ───────────────────────────────────────────────────────────────────────

# A space in Google Chat. Spaces are conversations between two or more users
# or 1:1 messages between a user and a Chat app.
#
# + name - Resource name of the space. Format: `spaces/{space}`
# + spaceType - The type of space
# + displayName - The display name of the space (for SPACE type only)
# + singleUserBotDm - Whether the space is a DM between a Chat app and a single human
# + spaceThreadingState - The threading state in the space
# + spaceDetails - Details about the space including description and rules
# + spaceHistoryState - The message history state for the space
# + importMode - Whether the space is in import mode
# + createTime - Time the space was created (RFC 3339)
# + lastActiveTime - Time of the most recent activity in the space (RFC 3339)
# + adminInstalled - Whether the Chat app was installed by a Google Workspace admin
# + membershipCount - Member counts for the space
# + accessSettings - Access settings of the space
# + spaceUri - URI for a user to access the space
# + externalUserAllowed - Whether the space allows external users
public type Space record {
    string name?;
    SpaceType spaceType?;
    string displayName?;
    boolean singleUserBotDm?;
    SpaceThreadingState spaceThreadingState?;
    SpaceDetails spaceDetails?;
    HistoryState spaceHistoryState?;
    boolean importMode?;
    string createTime?;
    string lastActiveTime?;
    boolean adminInstalled?;
    MembershipCount membershipCount?;
    AccessSettings accessSettings?;
    string spaceUri?;
    boolean externalUserAllowed?;
};

# Details about a space including description and rules.
#
# + description - Description of the space
# + guidelines - Guidelines or rules for the space
public type SpaceDetails record {
    string description?;
    string guidelines?;
};

# Count of members in a space.
#
# + joinedDirectHumanUserCount - Count of human users that have directly joined the space
# + joinedGroupCount - Count of Google Groups that have directly joined the space
public type MembershipCount record {
    int:Signed32 joinedDirectHumanUserCount?;
    int:Signed32 joinedGroupCount?;
};

# Access settings of a space.
#
# + accessState - The access state of the space
# + audience - The resource name of the target audience
public type AccessSettings record {
    AccessState accessState?;
    string audience?;
};

// ── User ────────────────────────────────────────────────────────────────────────

# A user in Google Chat. When returned as an output from a request, if your
# Chat app authenticates as a user, the output only populates the user's
# `name` and `type`.
#
# + name - Resource name of the user. Format: `users/{user}`
# + displayName - The user's display name
# + domainId - Unique identifier of the user's Google Workspace domain
# + type - The type of user (HUMAN or BOT)
# + isAnonymous - Whether the user is anonymous
public type User record {
    string name?;
    string displayName?;
    string domainId?;
    UserType 'type?;
    boolean isAnonymous?;
};

// ── Thread ──────────────────────────────────────────────────────────────────────

# A thread in a Google Chat space.
# Named `ChatThread` to avoid conflict with Ballerina's builtin `Thread` type.
#
# + name - Resource name of the thread. Format: `spaces/{space}/threads/{thread}`
# + threadKey - A client-specified thread identifier
public type ChatThread record {
    string name?;
    string threadKey?;
};

// ── Message ─────────────────────────────────────────────────────────────────────

# A message in a Google Chat space.
#
# + name - Resource name of the message. Format: `spaces/{space}/messages/{message}`
# + sender - Output only. The user who created the message
# + createTime - The time the message was created (RFC 3339)
# + lastUpdateTime - The time the message was last updated (RFC 3339)
# + deleteTime - The time the message was deleted (RFC 3339)
# + text - Plain-text body of the message
# + formattedText - Rich-text body with formatting markup
# + cardsV2 - Cards V2 attached to the message
# + annotations - Annotations associated with the message
# + thread - The thread the message belongs to
# + space - The space the message belongs to
# + fallbackText - Plain-text description of message cards
# + actionResponse - Parameters for configuring how the response is posted
# + argumentText - Plain-text body with Chat app mentions stripped out
# + slashCommand - Slash command information
# + attachment - Attachments uploaded with the message
# + matchedUrl - A URL in the message that matches a link preview pattern
# + threadReply - Whether the message is a reply in a thread
# + clientAssignedMessageId - A custom ID for the message
# + emojiReactionSummaries - Emoji reaction summaries on the message
# + privateMessageViewer - If set, the message is only visible to this user and the Chat app
# + deletionMetadata - Information about deletion of the message
# + quotedMessageMetadata - Information about a quoted message
# + attachedGifs - GIF images attached to the message
# + accessoryWidgets - Interactive widgets at the bottom of the message
public type Message record {
    string name?;
    User sender?;
    string createTime?;
    string lastUpdateTime?;
    string deleteTime?;
    string text?;
    string formattedText?;
    CardWithId[] cardsV2?;
    ChatAnnotation[] annotations?;
    ChatThread thread?;
    Space space?;
    string fallbackText?;
    ActionResponse actionResponse?;
    string argumentText?;
    SlashCommand slashCommand?;
    Attachment[] attachment?;
    MatchedUrl matchedUrl?;
    boolean threadReply?;
    string clientAssignedMessageId?;
    EmojiReactionSummary[] emojiReactionSummaries?;
    User privateMessageViewer?;
    DeletionMetadata deletionMetadata?;
    QuotedMessageMetadata quotedMessageMetadata?;
    AttachedGif[] attachedGifs?;
    AccessoryWidget[] accessoryWidgets?;
};

# Request payload for creating or updating a message.
#
# + text - Plain-text body of the message
# + cardsV2 - Cards V2 to attach to the message
# + thread - Thread to post the message in (for threaded replies)
# + fallbackText - Plain-text description of message cards
# + actionResponse - Parameters for configuring how the response is posted
# + accessoryWidgets - Interactive widgets at the bottom of the message
public type CreateMessageRequest record {|
    string text?;
    CardWithId[] cardsV2?;
    ChatThread thread?;
    string fallbackText?;
    ActionResponse actionResponse?;
    AccessoryWidget[] accessoryWidgets?;
|};

# Request payload for updating a message.
#
# + text - Plain-text body of the message
# + cardsV2 - Cards V2 to attach to the message
# + fallbackText - Plain-text description of message cards
# + accessoryWidgets - Interactive widgets at the bottom of the message
public type UpdateMessageRequest record {|
    string text?;
    CardWithId[] cardsV2?;
    string fallbackText?;
    AccessoryWidget[] accessoryWidgets?;
|};

// ── Membership ──────────────────────────────────────────────────────────────────

# Represents a membership relation in Google Chat, such as whether a user or
# Chat app is invited to, part of, or absent from a space.
#
# + name - Resource name. Format: `spaces/{space}/members/{member}`
# + state - Output only. State of the membership
# + role - User's role within the space
# + createTime - The creation time of the membership (RFC 3339)
# + deleteTime - The deletion time of the membership (RFC 3339)
# + member - The user or Chat app that the membership corresponds to
# + groupMember - The Google Group the membership corresponds to
public type Membership record {
    string name?;
    MembershipState state?;
    MembershipRole role?;
    string createTime?;
    string deleteTime?;
    User member?;
    Group groupMember?;
};

# A Google Group in Google Chat.
#
# + name - Resource name of the Google Group. Format: `groups/{group}`
public type Group record {
    string name?;
};

// ── Reaction ────────────────────────────────────────────────────────────────────

# A reaction to a message.
#
# + name - Resource name. Format: `spaces/{space}/messages/{message}/reactions/{reaction}`
# + user - The user who created the reaction
# + emoji - The emoji used for the reaction
public type Reaction record {
    string name?;
    User user?;
    Emoji emoji?;
};

# An emoji used for a reaction.
#
# + unicode - A basic emoji represented by a unicode string
# + customEmoji - A custom emoji
public type Emoji record {
    string unicode?;
    CustomEmoji customEmoji?;
};

# A custom emoji.
#
# + uid - The unique identifier of the custom emoji
public type CustomEmoji record {
    string uid?;
};

# Summary of an emoji reaction on a message.
#
# + emoji - The emoji associated with the reactions
# + reactionCount - The total number of reactions using this emoji
public type EmojiReactionSummary record {
    Emoji emoji?;
    int reactionCount?;
};

// ── Attachment ──────────────────────────────────────────────────────────────────

# An attachment in Google Chat.
#
# + name - Resource name. Format: `spaces/{space}/messages/{message}/attachments/{attachment}`
# + contentName - The original file name of the attachment
# + contentType - The content (MIME) type of the attachment
# + thumbnailUri - A thumbnail URL for the attachment
# + downloadUri - A download URL for the attachment
# + attachmentDataRef - Reference to attachment data uploaded via the Chat API
# + driveDataRef - Reference to a Google Drive file
# + source - The source of the attachment
public type Attachment record {
    string name?;
    string contentName?;
    string contentType?;
    string thumbnailUri?;
    string downloadUri?;
    AttachmentDataRef attachmentDataRef?;
    DriveDataRef driveDataRef?;
    string 'source?;
};

# Reference to the data of a Chat attachment.
#
# + resourceName - The resource name of the attachment data
# + attachmentUploadToken - Opaque token containing a reference to an uploaded attachment
public type AttachmentDataRef record {
    string resourceName?;
    string attachmentUploadToken?;
};

# Reference to a Google Drive file.
#
# + driveFileId - The ID of the Google Drive file
public type DriveDataRef record {
    string driveFileId?;
};

# Upload attachment request payload.
#
# + filename - The filename of the attachment
# + mediaBytes - The raw bytes of the attachment
public type UploadAttachmentRequest record {|
    string filename;
    byte[] mediaBytes;
|};

// ── Annotation ──────────────────────────────────────────────────────────────────

# An annotation on a message, highlighting a user mention, slash command, or link.
#
# + type - The type of annotation
# + startIndex - Start index (inclusive) in the plain-text message body
# + length - Length of the annotation in the plain-text message body
# + userMention - The user mentioned
# + slashCommand - The slash command
# + richLinkMetadata - Rich link metadata
public type ChatAnnotation record {
    AnnotationType 'type?;
    int:Signed32 startIndex?;
    int:Signed32 length?;
    UserMentionMetadata userMention?;
    SlashCommandMetadata slashCommand?;
    RichLinkMetadata richLinkMetadata?;
};

# Metadata about a user mention.
#
# + user - The user mentioned
# + type - The type of user mention
public type UserMentionMetadata record {
    User user?;
    string 'type?;
};

# Metadata about a slash command.
#
# + bot - The Chat app whose command was invoked
# + type - The type of slash command
# + commandName - The name of the invoked slash command
# + commandId - The command ID of the invoked slash command
# + triggersDialog - Whether the command triggers a dialog
public type SlashCommandMetadata record {
    User bot?;
    string 'type?;
    string commandName?;
    int:Signed32 commandId?;
    boolean triggersDialog?;
};

# Rich link metadata for a link in a message.
#
# + uri - The URI of the link
# + richLinkType - The type of rich link
# + driveLinkData - Drive link data (if DRIVE_FILE type)
# + chatSpaceLinkData - Chat space link data (if CHAT_SPACE type)
public type RichLinkMetadata record {
    string uri?;
    RichLinkType richLinkType?;
    DriveLinkData driveLinkData?;
    ChatSpaceLinkData chatSpaceLinkData?;
};

# Data for Google Drive links.
#
# + driveDataRef - Reference to a Google Drive file
# + mimeType - The MIME type of the Drive file
public type DriveLinkData record {
    DriveDataRef driveDataRef?;
    string mimeType?;
};

# Data for Chat space links.
#
# + space - The space of the linked resource. Format: `spaces/{space}`
# + thread - The thread of the linked resource. Format: `spaces/{space}/threads/{thread}`
# + message - The message of the linked resource. Format: `spaces/{space}/messages/{message}`
public type ChatSpaceLinkData record {
    string space?;
    string thread?;
    string message?;
};

// ── Slash Command ───────────────────────────────────────────────────────────────

# A slash command in a message.
#
# + commandId - The ID of the invoked slash command
public type SlashCommand record {
    int:Signed32 commandId?;
};

// ── URL Match ───────────────────────────────────────────────────────────────────

# A matched URL in a message.
#
# + url - The matched URL
public type MatchedUrl record {
    string url?;
};

// ── Deletion Metadata ───────────────────────────────────────────────────────────

# Information about a deleted message. A message is deleted when `delete_time`
# is set.
#
# + deletionType - Indicates who deleted the message
public type DeletionMetadata record {
    DeletionType deletionType?;
};

// ── Quoted Message ──────────────────────────────────────────────────────────────

# Information about a quoted message.
#
# + name - Resource name of the quoted message. Format: `spaces/{space}/messages/{message}`
# + lastUpdateTime - The last update time of the quoted message (RFC 3339)
public type QuotedMessageMetadata record {
    string name?;
    string lastUpdateTime?;
};

// ── GIF ─────────────────────────────────────────────────────────────────────────

# A GIF image attached to a message.
#
# + uri - The URL of the GIF image
public type AttachedGif record {
    string uri?;
};

// ── Cards V2 ────────────────────────────────────────────────────────────────────

# A card with a unique identifier, using the Cards V2 format.
#
# + cardId - A unique identifier for a card in a message
# + card - The card body
public type CardWithId record {
    string cardId?;
    Card card?;
};

# A Google Chat card (Cards V2 format).
#
# + header - The header of the card
# + sections - Sections of the card
# + cardActions - Card actions (menu items in the card toolbar)
# + name - Name of the card
public type Card record {
    CardHeader header?;
    Section[] sections?;
    CardAction[] cardActions?;
    string name?;
};

# Header of a card.
#
# + title - The title of the card header
# + subtitle - The subtitle of the card header
# + imageType - The shape used to crop the image
# + imageUrl - The URL of the image in the card header
# + imageAltText - The alternative text of the image
public type CardHeader record {
    string title?;
    string subtitle?;
    string imageType?;
    string imageUrl?;
    string imageAltText?;
};

# A section of a card.
#
# + header - Text that appears at the top of a section
# + widgets - Widgets in the section
# + collapsible - Whether the section is collapsible
# + uncollapsibleWidgetsCount - The number of uncollapsible widgets
public type Section record {
    string header?;
    Widget[] widgets?;
    boolean collapsible?;
    int:Signed32 uncollapsibleWidgetsCount?;
};

# A widget in a card section. Represented as a flexible JSON-like record since
# the widget schema is deeply nested and polymorphic (textParagraph, image,
# decoratedText, buttonList, selectionInput, dateTimePicker, grid, columns, etc.).
#
# + textParagraph - A text paragraph widget
# + image - An image widget
# + decoratedText - A decorated text widget
# + buttonList - A button list widget
# + selectionInput - A selection input widget
# + dateTimePicker - A date/time picker widget
# + divider - A horizontal divider
# + grid - A grid widget
# + columns - A columns widget
public type Widget record {
    TextParagraph textParagraph?;
    Image image?;
    DecoratedText decoratedText?;
    ButtonList buttonList?;
    json selectionInput?;
    json dateTimePicker?;
    json divider?;
    json grid?;
    json columns?;
};

# A text paragraph widget.
#
# + text - The text content
public type TextParagraph record {
    string text?;
};

# An image widget.
#
# + imageUrl - The URL of the image
# + altText - The alternative text of the image
# + onClick - The click action for the image
public type Image record {
    string imageUrl?;
    string altText?;
    OnClick onClick?;
};

# A decorated text widget.
#
# + icon - Deprecated icon for the widget
# + startIcon - The icon displayed in front of the text
# + topLabel - The label above the text
# + text - The primary text content
# + wrapText - Whether the text should wrap
# + bottomLabel - The label below the text
# + onClick - The click action for the widget
# + button - A button at the end of the row
# + switchControl - A switch control at the end of the row
public type DecoratedText record {
    json icon?;
    json startIcon?;
    string topLabel?;
    string text?;
    boolean wrapText?;
    string bottomLabel?;
    OnClick onClick?;
    Button button?;
    json switchControl?;
};

# A list of buttons.
#
# + buttons - Array of buttons
public type ButtonList record {
    Button[] buttons?;
};

# A button in a card.
#
# + text - The text of the button
# + icon - The icon of the button
# + color - The color of the button
# + onClick - The click action of the button
# + disabled - Whether the button is disabled
# + altText - The alternative text of the button
public type Button record {
    string text?;
    json icon?;
    json color?;
    OnClick onClick?;
    boolean disabled?;
    string altText?;
};

# An onClick action.
#
# + action - The action to perform (form submission)
# + openLink - The URL to open
# + openDynamicLinkAction - An add-on triggers this action when the form action needs to open a link
# + card - A card to push onto the card stack (for navigation)
public type OnClick record {
    Action action?;
    OpenLink openLink?;
    json openDynamicLinkAction?;
    Card card?;
};

# An action triggered by a widget interaction.
#
# + function - The method name of the action
# + parameters - List of action parameters
# + loadIndicator - The loading indicator type
# + persistValues - Whether to persist form values across actions
# + interaction - The interaction type (OPEN_DIALOG, etc.)
public type Action record {
    string 'function?;
    ActionParameter[] parameters?;
    string loadIndicator?;
    boolean persistValues?;
    string interaction?;
};

# A parameter for an action.
#
# + key - The name of the parameter
# + value - The value of the parameter
public type ActionParameter record {
    string 'key?;
    string value?;
};

# An open link action.
#
# + url - The URL to open
# + openAs - How to open the URL (FULL_SIZE, OVERLAY)
# + onClose - What to do when the link is closed
public type OpenLink record {
    string url?;
    string openAs?;
    string onClose?;
};

# A card action appears in the card toolbar menu.
#
# + actionLabel - The label of the action
# + onClick - The click action
public type CardAction record {
    string actionLabel?;
    OnClick onClick?;
};

// ── Accessory Widget ────────────────────────────────────────────────────────────

# An interactive widget that appears at the bottom of a message.
#
# + buttonList - A button list accessory widget
public type AccessoryWidget record {
    ButtonList buttonList?;
};

// ── Action Response ─────────────────────────────────────────────────────────────

# Parameters that a Chat app can use to configure how its response is posted.
#
# + type - The type of response
# + url - URL for user authentication or configuration
# + dialogAction - The action for a dialog
# + updatedWidget - An updated widget
public type ActionResponse record {
    ResponseType 'type?;
    string url?;
    DialogAction dialogAction?;
    json updatedWidget?;
};

# An action for a dialog.
#
# + dialog - The dialog body
# + actionStatus - The status of the dialog action
public type DialogAction record {
    Dialog dialog?;
    ActionStatus actionStatus?;
};

# A dialog body.
#
# + body - The card body of the dialog
public type Dialog record {
    Card body?;
};

# The status of a dialog action.
#
# + statusCode - The status code
# + userFacingMessage - A message to display to the user
public type ActionStatus record {
    string statusCode?;
    string userFacingMessage?;
};

// ── Form Action (Event Payload) ─────────────────────────────────────────────────

# A form action from user interaction.
#
# + actionMethodName - The method name of the action
# + parameters - List of action parameters
public type FormAction record {
    string actionMethodName?;
    ActionParameter[] parameters?;
};

// ── Common Event Object ─────────────────────────────────────────────────────────

# Information about the user's client platform, locale, and form inputs.
#
# + userLocale - The user's locale (e.g., "en-US")
# + hostApp - The host app the add-on is active in
# + platform - The platform of the user's client (WEB, IOS, ANDROID)
# + timeZone - The user's timezone
# + formInputs - Map of form inputs by widget name
# + parameters - Map of parameters passed to the action
public type CommonEventObject record {
    string userLocale?;
    string hostApp?;
    string platform?;
    TimeZone timeZone?;
    map<StringInputs> formInputs?;
    map<string> parameters?;
};

# Timezone information.
#
# + id - The IANA TZ time zone database code (e.g., "America/Toronto")
# + offset - The offset from UTC in milliseconds
public type TimeZone record {
    string id?;
    int offset?;
};

# String input values from a form widget.
#
# + value - The list of string values
public type StringInputs record {
    string[] value?;
};

// ── List Responses ──────────────────────────────────────────────────────────────

# Response from listing spaces.
#
# + nextPageToken - Token for the next page of results
# + spaces - List of spaces
public type ListSpacesResponse record {
    string nextPageToken?;
    Space[] spaces?;
};

# Response from listing messages in a space.
#
# + nextPageToken - Token for the next page of results
# + messages - List of messages
public type ListMessagesResponse record {
    string nextPageToken?;
    Message[] messages?;
};

# Response from listing memberships in a space.
#
# + nextPageToken - Token for the next page of results
# + memberships - List of memberships
public type ListMembershipsResponse record {
    string nextPageToken?;
    Membership[] memberships?;
};

# Response from listing reactions on a message.
#
# + nextPageToken - Token for the next page of results
# + reactions - List of reactions
public type ListReactionsResponse record {
    string nextPageToken?;
    Reaction[] reactions?;
};

// ── Space Event ─────────────────────────────────────────────────────────────────

# An event from a Google Chat space (from Workspace Events API).
#
# + name - Resource name. Format: `spaces/{space}/spaceEvents/{spaceEvent}`
# + eventTime - The time the event occurred (RFC 3339)
# + eventType - The type of the space event
# + payload - The event payload (varies by event type)
public type SpaceEvent record {
    string name?;
    string eventTime?;
    string eventType?;
    json payload?;
};

# Response from listing space events.
#
# + nextPageToken - Token for the next page of results
# + spaceEvents - List of space events
public type ListSpaceEventsResponse record {
    string nextPageToken?;
    SpaceEvent[] spaceEvents?;
};
