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
    ROLE_MANAGER,
    ROLE_ASSISTANT_MANAGER
}

# Type of an annotation in a message.
public enum AnnotationType {
    ANNOTATION_TYPE_UNSPECIFIED,
    USER_MENTION,
    SLASH_COMMAND,
    RICH_LINK,
    CUSTOM_EMOJI
}

# Type of a rich link.
public enum RichLinkType {
    RICH_LINK_TYPE_UNSPECIFIED,
    DRIVE_FILE,
    CHAT_SPACE,
    GMAIL_MESSAGE,
    MEET_SPACE,
    CALENDAR_EVENT
}

# Type of an action response from a Chat app.
public enum ResponseType {
    TYPE_UNSPECIFIED,
    NEW_MESSAGE,
    UPDATE_MESSAGE,
    UPDATE_USER_MESSAGE_CARDS,
    REQUEST_CONFIG,
    DIALOG,
    UPDATE_WIDGET
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
    WIDGET_UPDATED,
    APP_COMMAND,
    APP_HOME,
    SUBMIT_FORM
}

# Type of a Chat app command.
public enum AppCommandType {
    APP_COMMAND_TYPE_UNSPECIFIED,
    SLASH_COMMAND,
    QUICK_COMMAND
}

public enum MessageReplyOption {
    MESSAGE_REPLY_OPTION_UNSPECIFIED,
    REPLY_MESSAGE_FALLBACK_TO_NEW_THREAD,
    REPLY_MESSAGE_OR_FAIL
}

// ── Space ───────────────────────────────────────────────────────────────────────

# Predefined permission settings for a space (input only when creating a named space).
public enum PredefinedPermissionSettings {
    PREDEFINED_PERMISSION_SETTINGS_UNSPECIFIED,
    COLLABORATION_SPACE,
    ANNOUNCEMENT_SPACE
}

# Controls whether space managers and/or members are allowed to perform a specific action.
#
# + managersAllowed - Whether space managers (ROLE_MANAGER) have this permission
# + membersAllowed - Whether regular members (ROLE_MEMBER) have this permission
# + assistantManagersAllowed - Whether assistant managers (ROLE_ASSISTANT_MANAGER) have this permission
public type PermissionSetting record {
    boolean managersAllowed?;
    boolean membersAllowed?;
    boolean assistantManagersAllowed?;
};

# Fine-grained permission settings for an existing named space.
#
# + manageMembersAndGroups - Permission to manage members and groups
# + modifySpaceDetails - Permission to update space name, avatar, description and guidelines
# + toggleHistory - Permission to toggle space history on and off
# + useAtMentionAll - Permission to use @all in a space
# + manageApps - Permission to manage apps in a space
# + manageWebhooks - Permission to manage webhooks in a space
# + postMessages - Permission to post messages (output only)
# + replyMessages - Permission to reply to messages
public type PermissionSettings record {
    PermissionSetting manageMembersAndGroups?;
    PermissionSetting modifySpaceDetails?;
    PermissionSetting toggleHistory?;
    PermissionSetting useAtMentionAll?;
    PermissionSetting manageApps?;
    PermissionSetting manageWebhooks?;
    PermissionSetting postMessages?;
    PermissionSetting replyMessages?;
};

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
# + importModeExpireTime - Time when the space will be auto-deleted if it remains in import mode (RFC 3339)
# + customer - Immutable customer ID of the domain; format: `customers/{customer}`
# + predefinedPermissionSettings - Input only predefined permission settings when creating a space
# + permissionSettings - Fine-grained permission settings for an existing named space
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
    string importModeExpireTime?;
    string customer?;
    PredefinedPermissionSettings predefinedPermissionSettings?;
    PermissionSettings permissionSettings?;
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
# + attachment - User-uploaded attachments to include in the message
# + quotedMessageMetadata - Information about the quoted message
# + accessoryWidgets - Interactive widgets at the bottom of the message
public type CreateMessageRequest record {|
    string text?;
    CardWithId[] cardsV2?;
    ChatThread thread?;
    string fallbackText?;
    ActionResponse actionResponse?;
    Attachment[] attachment?;
    QuotedMessageMetadata quotedMessageMetadata?;
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

# Response returned after uploading an attachment.
#
# + attachmentDataRef - Reference to the uploaded attachment
public type UploadAttachmentResponse record {|
    AttachmentDataRef attachmentDataRef?;
|};

// ── Annotation ──────────────────────────────────────────────────────────────────

# An annotation on a message, highlighting a user mention, slash command, link, or custom emoji.
#
# + type - The type of annotation
# + startIndex - Start index (inclusive) in the plain-text message body
# + length - Length of the annotation in the plain-text message body
# + userMention - The user mentioned
# + slashCommand - The slash command
# + richLinkMetadata - Rich link metadata
# + customEmojiMetadata - Custom emoji metadata (for CUSTOM_EMOJI annotations)
public type ChatAnnotation record {
    AnnotationType 'type?;
    int:Signed32 startIndex?;
    int:Signed32 length?;
    UserMentionMetadata userMention?;
    SlashCommandMetadata slashCommand?;
    RichLinkMetadata richLinkMetadata?;
    CustomEmojiMetadata customEmojiMetadata?;
};

# Metadata for a custom emoji annotation in a message.
#
# + customEmoji - The custom emoji
public type CustomEmojiMetadata record {
    CustomEmoji customEmoji?;
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
# + meetSpaceLinkData - Meet space link data (if MEET_SPACE type)
# + calendarEventLinkData - Calendar event link data (if CALENDAR_EVENT type)
public type RichLinkMetadata record {
    string uri?;
    RichLinkType richLinkType?;
    DriveLinkData driveLinkData?;
    ChatSpaceLinkData chatSpaceLinkData?;
    MeetSpaceLinkData meetSpaceLinkData?;
    CalendarEventLinkData calendarEventLinkData?;
};

# Data for Meet space rich links.
#
# + meetSpaceUri - The URI of the Meet space
public type MeetSpaceLinkData record {
    string meetSpaceUri?;
};

# Data for Calendar event rich links.
#
# + calendarEventId - The ID of the Calendar event
public type CalendarEventLinkData record {
    string calendarEventId?;
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

# Quote type for a quoted message.
public enum QuoteType {
    QUOTE_TYPE_UNSPECIFIED,
    REPLY,
    FORWARD
}

# Information about a quoted message.
#
# + name - Resource name of the quoted message. Format: `spaces/{space}/messages/{message}`
# + lastUpdateTime - The last update time of the quoted message (RFC 3339)
# + quoteType - The type of quote (REPLY or FORWARD)
# + quotedMessageSnapshot - Output only. A snapshot of the quoted message's content
# + forwardedMetadata - Output only. Metadata about the source space (for FORWARD type)
public type QuotedMessageMetadata record {
    string name?;
    string lastUpdateTime?;
    QuoteType quoteType?;
    QuotedMessageSnapshot quotedMessageSnapshot?;
    ForwardedMetadata forwardedMetadata?;
};

# A snapshot of the content of a quoted message.
#
# + sender - Output only. The quoted message's author resource name
# + text - Output only. Snapshot of the quoted message's plain text content
# + formattedText - Output only. Text with formatting markup (FORWARD type only)
# + annotations - Output only. Annotations parsed from the text body (FORWARD type only)
# + attachments - Output only. Copies of the attachment metadata (FORWARD type only)
public type QuotedMessageSnapshot record {
    string sender?;
    string text?;
    string formattedText?;
    ChatAnnotation[] annotations?;
    Attachment[] attachments?;
};

# Metadata about the source space of a forwarded message.
#
# + space - Output only. Resource name of the source space. Format: `spaces/{space}`
# + spaceDisplayName - Output only. Display name of the source space at time of forwarding
public type ForwardedMetadata record {
    string space?;
    string spaceDisplayName?;
};

// ── GIF ─────────────────────────────────────────────────────────────────────────

# A GIF image attached to a message.
#
# + uri - The URL of the GIF image
public type AttachedGif record {
    string uri?;
};

// ── Cards V2 ────────────────────────────────────────────────────────────────────

# Shape used to crop an image in a card header or icon.
public enum ImageType {
    SQUARE,
    CIRCLE
}

# Divider style between card sections.
public enum DividerStyle {
    DIVIDER_STYLE_UNSPECIFIED,
    SOLID_DIVIDER,
    NO_DIVIDER
}

# How a card is displayed in an add-on (not used in Chat apps).
public enum DisplayStyle {
    DISPLAY_STYLE_UNSPECIFIED,
    PEEK,
    REPLACE
}

# Horizontal alignment of a widget within a column.
public enum HorizontalAlignment {
    HORIZONTAL_ALIGNMENT_UNSPECIFIED,
    START,
    CENTER,
    END
}

# Vertical alignment of content within a column cell.
public enum VerticalAlignment {
    VERTICAL_ALIGNMENT_UNSPECIFIED,
    CENTER,
    TOP,
    BOTTOM
}

# Visibility of a widget (Workspace Studio add-ons only).
public enum Visibility {
    VISIBILITY_UNSPECIFIED,
    VISIBLE,
    HIDDEN
}

# Syntax used to render TextParagraph text.
public enum TextSyntax {
    TEXT_SYNTAX_UNSPECIFIED,
    HTML,
    MARKDOWN
}

# Type of a Button (filled, outlined, etc.).
public enum ButtonType {
    BUTTON_TYPE_UNSPECIFIED,
    OUTLINED,
    FILLED,
    FILLED_TONAL,
    BORDERLESS
}

# Type of a SwitchControl widget.
public enum ControlType {
    SWITCH,
    CHECKBOX,
    CHECK_BOX
}

# Type of a SelectionInput widget.
public enum SelectionType {
    CHECK_BOX,
    RADIO_BUTTON,
    SWITCH,
    DROPDOWN,
    MULTI_SELECT
}

# Type of a DateTimePicker widget.
public enum DateTimePickerType {
    DATE_AND_TIME,
    DATE_ONLY,
    TIME_ONLY
}

# Type of a TextInput widget.
public enum TextInputType {
    SINGLE_LINE,
    MULTIPLE_LINE
}

# Layout of a ChipList widget.
public enum ChipListLayout {
    LAYOUT_UNSPECIFIED,
    WRAPPED,
    HORIZONTAL_SCROLLABLE
}

# Layout of a GridItem.
public enum GridItemLayout {
    GRID_ITEM_LAYOUT_UNSPECIFIED,
    TEXT_BELOW,
    TEXT_ABOVE
}

# Image crop type.
public enum ImageCropType {
    IMAGE_CROP_TYPE_UNSPECIFIED,
    SQUARE,
    CIRCLE,
    RECTANGLE_CUSTOM,
    RECTANGLE_4_3
}

# Border type.
public enum BorderType {
    BORDER_TYPE_UNSPECIFIED,
    NO_BORDER,
    STROKE
}

# How a column sizes itself horizontally.
public enum HorizontalSizeStyle {
    HORIZONTAL_SIZE_STYLE_UNSPECIFIED,
    FILL_AVAILABLE_SPACE,
    FILL_MINIMUM_SPACE
}

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
# + sectionDividerStyle - Divider style between header, sections and footer
# + cardActions - Card actions (menu items in the card toolbar; add-ons only)
# + name - Name of the card (used for card navigation; add-ons only)
# + fixedFooter - Fixed footer shown at the bottom of the card
# + displayStyle - How the card is displayed (add-ons only)
# + peekCardHeader - Peek card header for contextual content (add-ons only)
public type Card record {
    CardHeader header?;
    Section[] sections?;
    DividerStyle sectionDividerStyle?;
    CardAction[] cardActions?;
    string name?;
    CardFixedFooter fixedFooter?;
    DisplayStyle displayStyle?;
    CardHeader peekCardHeader?;
};

# Fixed footer displayed at the bottom of a card.
#
# + primaryButton - The primary button in the footer
# + secondaryButton - The secondary button in the footer
public type CardFixedFooter record {
    Button primaryButton?;
    Button secondaryButton?;
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
    ImageType imageType?;
    string imageUrl?;
    string imageAltText?;
};

# A section of a card.
#
# + header - Text that appears at the top of a section
# + widgets - Widgets in the section
# + collapsible - Whether the section is collapsible
# + uncollapsibleWidgetsCount - The number of widgets always visible when collapsed
# + id - Unique ID for the section (Workspace Studio add-ons only)
# + collapseControl - Custom expand/collapse buttons (optional)
public type Section record {
    string header?;
    Widget[] widgets?;
    boolean collapsible?;
    int uncollapsibleWidgetsCount?;
    string id?;
    CollapseControl collapseControl?;
};

# Custom expand/collapse buttons for a collapsible section.
#
# + horizontalAlignment - Alignment of the expand/collapse button
# + expandButton - Custom button shown to expand the section
# + collapseButton - Custom button shown to collapse the section
public type CollapseControl record {
    HorizontalAlignment horizontalAlignment?;
    Button expandButton?;
    Button collapseButton?;
};

# A widget in a card section.
#
# + horizontalAlignment - Horizontal alignment of the widget within a column
# + id - Unique ID assigned to the widget (Workspace Studio add-ons only)
# + visibility - Whether the widget is visible or hidden (Workspace Studio add-ons only)
# + textParagraph - A text paragraph widget
# + image - An image widget
# + decoratedText - A decorated text widget
# + buttonList - A button list widget
# + textInput - A text input widget
# + selectionInput - A selection input widget (checkboxes, radio buttons, dropdown, etc.)
# + dateTimePicker - A date/time picker widget
# + divider - A horizontal line divider
# + grid - A grid widget
# + columns - A columns layout widget
# + carousel - A carousel of nested widgets
# + chipList - A list of chips
public type Widget record {
    HorizontalAlignment horizontalAlignment?;
    string id?;
    Visibility visibility?;
    TextParagraph textParagraph?;
    Image image?;
    DecoratedText decoratedText?;
    ButtonList buttonList?;
    TextInput textInput?;
    SelectionInput selectionInput?;
    DateTimePicker dateTimePicker?;
    Divider divider?;
    Grid grid?;
    Columns columns?;
    Carousel carousel?;
    ChipList chipList?;
};

# A text paragraph widget.
#
# + text - The text content (supports simple HTML formatting)
# + maxLines - Maximum lines to display before truncating with a "show more" button
# + textSyntax - The syntax used to render the text (HTML or MARKDOWN)
public type TextParagraph record {
    string text?;
    int maxLines?;
    TextSyntax textSyntax?;
};

# A horizontal line divider widget.
public type Divider record {
};

# An image widget.
#
# + imageUrl - The HTTPS URL of the image
# + altText - The alternative text for accessibility
# + onClick - Action triggered when the user clicks the image
public type Image record {
    string imageUrl?;
    string altText?;
    OnClick onClick?;
};

# An icon displayed in a card widget.
#
# + altText - Accessibility label for the icon
# + imageType - The shape used to crop the icon image
# + knownIcon - A built-in Chat icon specified by name (e.g. "EMAIL", "PERSON")
# + iconUrl - A custom icon specified by HTTPS URL
# + materialIcon - A Google Material Icon
public type Icon record {
    string altText?;
    ImageType imageType?;
    string knownIcon?;
    string iconUrl?;
    MaterialIcon materialIcon?;
};

# A Google Material Icon.
# Reference: https://fonts.google.com/icons
#
# + name - The icon name defined in the Material Symbols font (e.g. "home", "star")
# + fill - Whether the icon is rendered filled (true) or outlined (false)
# + weight - Stroke weight of the icon; one of 100, 200, 300, 400, 500, 600, 700
# + grade - Visual emphasis: negative (−25), default (0), or high emphasis (200)
public type MaterialIcon record {
    string name?;
    boolean fill?;
    int weight?;
    int grade?;
};

# An RGBA color value.
#
# + red - Red channel value in [0.0, 1.0]
# + green - Green channel value in [0.0, 1.0]
# + blue - Blue channel value in [0.0, 1.0]
# + alpha - Alpha (opacity) value in [0.0, 1.0]
public type Color record {
    float red?;
    float green?;
    float blue?;
    float alpha?;
};

# A decorated text widget with optional icon, labels, and action.
#
# + icon - Deprecated. Use startIcon instead
# + startIcon - Icon displayed in front of the text
# + startIconVerticalAlignment - Vertical alignment of the start icon
# + topLabel - Label above the primary text
# + text - The primary text content
# + wrapText - Whether the text wraps to the next line
# + bottomLabel - Label below the primary text
# + onClick - Action triggered when the widget is clicked
# + button - A button at the end of the row
# + switchControl - A switch/checkbox at the end of the row
# + endIcon - An icon at the end of the row
public type DecoratedText record {
    Icon icon?;
    Icon startIcon?;
    VerticalAlignment startIconVerticalAlignment?;
    string topLabel?;
    string text?;
    boolean wrapText?;
    string bottomLabel?;
    OnClick onClick?;
    Button button?;
    SwitchControl switchControl?;
    Icon endIcon?;
};

# A switch or checkbox control.
#
# + name - The name identifying the switch in form input data
# + value - The value returned in form data when selected
# + selected - Whether the switch is selected by default
# + onChangeAction - Action triggered when the switch state changes
# + controlType - Visual style of the control (SWITCH, CHECKBOX)
public type SwitchControl record {
    string name?;
    string value?;
    boolean selected?;
    Action onChangeAction?;
    ControlType controlType?;
};

# A list of buttons.
#
# + buttons - Array of buttons
public type ButtonList record {
    Button[] buttons?;
};

# A button in a card.
#
# + text - The button label text
# + icon - The icon for the button
# + color - The fill color of the button
# + onClick - Action triggered when the button is clicked
# + disabled - Whether the button is disabled
# + altText - Accessibility label for the button
# + type - The button style (OUTLINED, FILLED, etc.)
public type Button record {
    string text?;
    Icon icon?;
    Color color?;
    OnClick onClick?;
    boolean disabled?;
    string altText?;
    ButtonType 'type?;
};

# An onClick action.
#
# + action - Action to perform (form submission or function call)
# + openLink - URL to open
# + openDynamicLinkAction - Add-on action that opens a dynamic link (add-ons only)
# + card - A card to push onto the card stack (add-ons only)
# + overflowMenu - An overflow menu to open
public type OnClick record {
    Action action?;
    OpenLink openLink?;
    Action openDynamicLinkAction?;
    Card card?;
    OverflowMenu overflowMenu?;
};

# An overflow menu displayed when an OnClick is triggered.
#
# + items - The list of menu items
public type OverflowMenu record {
    OverflowMenuItem[] items?;
};

# A single item in an overflow menu.
#
# + startIcon - Icon displayed before the item text
# + text - The item label
# + onClick - Action triggered when the item is clicked
# + disabled - Whether the item is disabled
public type OverflowMenuItem record {
    Icon startIcon?;
    string text?;
    OnClick onClick?;
    boolean disabled?;
};

# An action triggered by a widget interaction.
#
# + function - The custom function to invoke
# + parameters - List of action parameters
# + loadIndicator - Loading indicator shown while the action runs
# + persistValues - Whether form values are preserved after the action
# + interaction - Interaction type, e.g. OPEN_DIALOG (Chat apps only)
# + requiredWidgets - Names of widgets required for a valid submission
# + allWidgetsAreRequired - If true, all widgets are treated as required
public type Action record {
    string 'function?;
    ActionParameter[] parameters?;
    string loadIndicator?;
    boolean persistValues?;
    string interaction?;
    string[] requiredWidgets?;
    boolean allWidgetsAreRequired?;
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

# A card action appears in the card toolbar menu (add-ons only).
#
# + actionLabel - The label of the action
# + onClick - The click action
public type CardAction record {
    string actionLabel?;
    OnClick onClick?;
};

# A text input widget.
#
# + name - The name that identifies the input in form data
# + label - The label displayed above the text field
# + hintText - Helper text displayed inside the text field when empty
# + value - The pre-filled value
# + type - Whether the input is single-line or multi-line
# + onChangeAction - Action triggered on every keystroke
# + initialSuggestions - Autocomplete suggestions shown on focus
# + autoCompleteAction - Server-side action to fetch autocomplete suggestions
# + validation - Validation rules for the input
# + placeholderText - Placeholder text shown in multi-select chips
public type TextInput record {
    string name?;
    string label?;
    string hintText?;
    string value?;
    TextInputType 'type?;
    Action onChangeAction?;
    Suggestions initialSuggestions?;
    Action autoCompleteAction?;
    Validation validation?;
    string placeholderText?;
};

# Autocomplete suggestion items for a text input.
#
# + items - The list of suggestion items
public type Suggestions record {
    SuggestionItem[] items?;
};

# A single autocomplete suggestion item.
#
# + text - The suggestion text shown to the user
public type SuggestionItem record {
    string text?;
};

# Validation rules for a TextInput widget.
#
# + characterLimit - Maximum number of characters allowed
# + inputType - Type of input allowed (e.g. EMAIL, INTEGER)
public type Validation record {
    int characterLimit?;
    string inputType?;
};

# A selection input widget (checkboxes, radio buttons, switch, dropdown, multi-select).
#
# + name - The name identifying the selection in form data
# + label - The label displayed above the selection control
# + type - The type of selection control
# + items - The list of selectable items
# + onChangeAction - Action triggered when the selection changes
# + multiSelectMaxSelectedItems - Max number of items a user can select (multi-select)
# + multiSelectMinQueryLength - Min characters before autocomplete is triggered (multi-select)
# + hintText - Helper text for multi-select inputs
# + externalDataSource - Action to fetch external data source items
public type SelectionInput record {
    string name?;
    string label?;
    SelectionType 'type?;
    SelectionItem[] items?;
    Action onChangeAction?;
    int multiSelectMaxSelectedItems?;
    int multiSelectMinQueryLength?;
    string hintText?;
    Action externalDataSource?;
};

# A selectable item in a SelectionInput.
#
# + text - The display text for the item
# + value - The form data value submitted when selected
# + selected - Whether the item is pre-selected
# + bottomText - Description text displayed below the item text
# + startIconUri - HTTPS URL of an icon displayed before the item text
public type SelectionItem record {
    string text?;
    string value?;
    boolean selected?;
    string bottomText?;
    string startIconUri?;
};

# A date, time, or date-and-time picker widget.
#
# + name - The name identifying the picker in form data
# + label - The label displayed above the picker
# + type - Whether to show date, time, or both
# + valueMsEpoch - Pre-filled value as milliseconds since Unix epoch (string-encoded int64)
# + timezoneOffsetDate - UTC offset in minutes for date-only pickers
# + onChangeAction - Action triggered when the user picks a value
public type DateTimePicker record {
    string name?;
    string label?;
    DateTimePickerType 'type?;
    string valueMsEpoch?;
    int timezoneOffsetDate?;
    Action onChangeAction?;
};

# A grid widget displaying a collection of items.
#
# + title - Text shown at the top of the grid
# + items - The items to display in the grid
# + borderStyle - The border style to apply to each grid item
# + columnCount - Number of columns in the grid
# + onClick - Action triggered when any grid item is clicked (unless the item has its own onClick)
public type Grid record {
    string title?;
    GridItem[] items?;
    BorderStyle borderStyle?;
    int columnCount?;
    OnClick onClick?;
};

# An item in a grid widget.
#
# + id - Identifier for the item, returned in the grid's onClick parameters
# + image - The image displayed for the item
# + title - Title text for the item
# + subtitle - Subtitle text for the item
# + layout - How the text is positioned relative to the image
public type GridItem record {
    string id?;
    ImageComponent image?;
    string title?;
    string subtitle?;
    GridItemLayout layout?;
};

# An image component used in grid and other widgets.
#
# + imageUri - The HTTPS URL of the image
# + altText - Accessibility label for the image
# + cropStyle - How to crop the image
# + borderStyle - Border to apply to the image
public type ImageComponent record {
    string imageUri?;
    string altText?;
    ImageCropStyle cropStyle?;
    BorderStyle borderStyle?;
};

# Defines how an image is cropped.
#
# + type - The crop type (SQUARE, CIRCLE, RECTANGLE_CUSTOM, etc.)
# + aspectRatio - Aspect ratio for RECTANGLE_CUSTOM crop type (width / height)
public type ImageCropStyle record {
    ImageCropType 'type?;
    float aspectRatio?;
};

# Border style applied to a widget or image.
#
# + type - The border type (NO_BORDER or STROKE)
# + strokeColor - The color of the border stroke
# + cornerRadius - The corner radius in pixels
public type BorderStyle record {
    BorderType 'type?;
    Color strokeColor?;
    int cornerRadius?;
};

# A columns layout widget containing up to 2 columns.
#
# + columnItems - The columns to display
public type Columns record {
    Column[] columnItems?;
};

# A single column within a Columns widget.
#
# + horizontalSizeStyle - How the column sizes itself horizontally
# + horizontalAlignment - Horizontal alignment of widgets within the column
# + verticalAlignment - Vertical alignment of widgets within the column
# + widgets - The widgets within this column
public type Column record {
    HorizontalSizeStyle horizontalSizeStyle?;
    HorizontalAlignment horizontalAlignment?;
    VerticalAlignment verticalAlignment?;
    Widget[] widgets?;
};

# A carousel containing a collection of nested widgets.
#
# + carouselCards - The carousel cards to display
public type Carousel record {
    CarouselCard[] carouselCards?;
};

# A card within a carousel.
#
# + widgets - The main widgets in the carousel card
# + footerWidgets - Footer widgets shown at the bottom of the carousel card
public type CarouselCard record {
    NestedWidget[] widgets?;
    NestedWidget[] footerWidgets?;
};

# A widget that can be nested inside a CarouselCard.
# Only a subset of widget types are supported.
#
# + textParagraph - A text paragraph
# + buttonList - A list of buttons
# + image - An image
public type NestedWidget record {
    TextParagraph textParagraph?;
    ButtonList buttonList?;
    Image image?;
};

# A list of chips.
#
# + layout - The layout of the chip list (WRAPPED or HORIZONTAL_SCROLLABLE)
# + chips - The chips to display
public type ChipList record {
    ChipListLayout layout?;
    Chip[] chips?;
};

# A single chip in a ChipList.
#
# + icon - The icon displayed in the chip
# + label - The text label of the chip
# + onClick - Action triggered when the chip is clicked
# + disabled - Whether the chip is disabled
# + altText - Accessibility label for the chip
public type Chip record {
    Icon icon?;
    string label?;
    OnClick onClick?;
    boolean disabled?;
    string altText?;
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
# + updatedWidget - Widget autocomplete results (for UPDATE_WIDGET response type)
public type ActionResponse record {
    ResponseType 'type?;
    string url?;
    DialogAction dialogAction?;
    UpdatedWidget updatedWidget?;
};

# Updated widget with autocomplete suggestions, returned for UPDATE_WIDGET responses.
#
# + widget - The ID of the updated widget
# + suggestions - Input only. List of widget autocomplete results
public type UpdatedWidget record {
    string widget?;
    SelectionItems suggestions?;
};

# A list of selection items for widget autocomplete.
#
# + items - The list of selection items
public type SelectionItems record {
    json[] items?;
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
# + formInputs - Map of widget ID to input values; value type depends on widget
# + parameters - Map of additional parameters passed to the action
# + invokedFunction - Name of the function invoked (for Chat apps)
public type CommonEventObject record {
    string userLocale?;
    string hostApp?;
    string platform?;
    TimeZone timeZone?;
    map<Inputs> formInputs?;
    map<string> parameters?;
    string invokedFunction?;
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

# Date and time input values from a DateTimePicker widget that accepts both a date and time.
#
# + msSinceEpoch - Time since epoch, in milliseconds
# + hasDate - Whether the input includes a calendar date
# + hasTime - Whether the input includes a timestamp
public type DateTimeInput record {
    string msSinceEpoch?;
    boolean hasDate?;
    boolean hasTime?;
};

# Date input values from a DateTimePicker widget that only accepts date values.
#
# + msSinceEpoch - Time since epoch, in milliseconds
public type DateInput record {
    string msSinceEpoch?;
};

# Time input values from a DateTimePicker widget that only accepts time values.
#
# + hours - The hour on a 24-hour clock
# + minutes - The number of minutes past the hour (0–59)
public type TimeInput record {
    int hours?;
    int minutes?;
};

# Union of input types that a user can submit from a card or dialog widget.
# Exactly one of the fields will be populated depending on the widget type.
#
# + stringInputs - String values from text inputs or selection inputs
# + dateTimeInput - Date and time values from a date-time picker
# + dateInput - Date-only values from a date picker
# + timeInput - Time-only values from a time picker
public type Inputs record {
    StringInputs stringInputs?;
    DateTimeInput dateTimeInput?;
    DateInput dateInput?;
    TimeInput timeInput?;
};

// ── App Command Metadata ─────────────────────────────────────────────────────────

# Metadata about a Chat app command, present for APP_COMMAND interaction events.
#
# + appCommandId - The ID for the command specified in the Chat API configuration
# + appCommandType - The type of Chat app command (slash or quick command)
public type AppCommandMetadata record {
    int appCommandId?;
    AppCommandType appCommandType?;
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

# Response from searching spaces (admin access).
#
# + spaces - Page of spaces matching the search query
# + nextPageToken - Token to retrieve the next page. Empty if no more pages
# + totalSize - Total number of spaces matching the query across all pages.
#               An estimate if the total exceeds 10,000
public type SearchSpacesResponse record {
    Space[] spaces?;
    string nextPageToken?;
    int totalSize?;
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
