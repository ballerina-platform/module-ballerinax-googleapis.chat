## Overview

[Google Chat](https://workspace.google.com/products/chat/) is a communication platform from Google, designed for teams and businesses as part of Google Workspace.

The `ballerinax/googleapis.chat` package provides both:

- A **REST client** (`chat:Client`) for the [Google Chat API](https://developers.google.com/workspace/chat/api/reference/rest) — create spaces, send messages, manage memberships, upload attachments, etc.
- A **webhook listener** (`chat:Listener`) that receives Google Chat interaction events (messages, slash commands, card clicks, dialog submissions, app-home opens) over HTTP and dispatches them to typed `remote function`s on a `chat:ChatService`.

The listener runs as a plain HTTPS endpoint that Google Chat POSTs events to directly. It supports three authentication mechanisms: **service account** (recommended for bots), **OAuth 2.0** (for user-scoped actions such as attachment uploads), and short-lived **bearer tokens** (for quick tests).

## Setup guide

To use the Google Chat connector, you must have access to the Google Chat API through a [Google Cloud Platform (GCP)](https://console.cloud.google.com/) account with a project under it. If you do not have a GCP account, you can sign up for one [here](https://cloud.google.com/).

### Step 1: Create a Google Cloud Platform project

1. Open the [Google Cloud Platform Console](https://console.cloud.google.com/).

2. Click the project drop-down menu and select an existing project, or create a new one for your Chat app.

    ![GCP Console Project View](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/gcp-console-project-view.png)

### Step 2: Enable the Google Chat API

1. Navigate to **APIs & Services → Library** and enable the **Google Chat API**.

    ![Enable Google Chat API](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/enable-chat-api.png)

### Step 3: Expose your local listener (development)

Google Chat must reach the listener over a public HTTPS URL. For local development the easiest option is [`ngrok`](https://ngrok.com/):

```bash
ngrok http 8000
```

Copy the `https://<sub>.ngrok-free.app` URL it prints — you will use this both in the next step and as the listener's `endpointUrl` in code.

For production, deploy the listener behind any HTTPS-terminating load balancer or reverse proxy; what matters is that Google Chat can reach a stable HTTPS URL.

### Step 4: Configure the Chat app

1. In the Google Cloud Console, open the **Google Chat API** page and select the **Configuration** tab.

    ![Chat App Configuration](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/chat-app-configuration.png)

2. Provide the **App name**, **Avatar URL** and **Description**.

3. Under **Interactive features**, enable the features your app needs (receive 1:1 messages, join spaces, slash commands, etc.).

4. Under **Connection settings**, choose **HTTP endpoint URL** and paste the ngrok (or production) HTTPS URL from Step 3.

5. Set **Authentication audience** to either:

    - the same **HTTP endpoint URL** (use `HttpEndpointUrlConfig` / `endpointUrl` in the listener), or
    - your **Project number** (use `ProjectNumberConfig` / `projectNumber` in the listener).

    The value you choose here must match what your service annotation declares — the listener uses it to validate the `aud` claim of the Google-signed bearer token on every incoming request.

    ![Connection Settings](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/connection-settings.png)

6. Under **Visibility**, add the email addresses of users or Google Workspace domains that can install your app.

### Step 5: Choose an authentication method

The connector supports three authentication modes. Pick the one that matches your use case.

#### Option A — Service Account (recommended for bots)

A service account lets your app act as itself — ideal for bots that post messages, manage memberships, or run continuously.

1. Navigate to **IAM & Admin → Service Accounts** and click **Create service account**.

    ![Create Service Account](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/create-service-account.png)

2. Give it a name, click **Done**, then open the created service account and go to the **Keys** tab.

3. Click **Add key → Create new key → JSON** and save the downloaded JSON file securely. You will reference its path from `Config.toml`.

    ![Download Service Account Key](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/download-sa-key.png)

#### Option B — OAuth 2.0 (for user-scoped actions)

OAuth 2.0 lets your app act on behalf of a signed-in user — required for operations like attachment uploads that need user scopes.

1. Open **APIs & Services → OAuth consent screen**, configure your consent screen, and add the Chat scopes your app uses (for example `https://www.googleapis.com/auth/chat.messages`, `https://www.googleapis.com/auth/chat.spaces`).

    ![OAuth Consent Screen](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/consent-screen.png)

2. Open **APIs & Services → Credentials → Create credentials → OAuth client ID**.

    ![Create OAuth Client](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/create-credentials.png)

3. Fill in the form:

    | Field                    | Value                                              |
    | ------------------------ | -------------------------------------------------- |
    | Application type         | Web Application                                    |
    | Name                     | ChatConnector                                      |
    | Authorized Redirect URIs | `https://developers.google.com/oauthplayground`    |

4. Save the **Client ID** and **Client secret**.

5. Use the [OAuth 2.0 Playground](https://developers.google.com/oauthplayground) to obtain a refresh token: open the gear icon → "Use your own OAuth credentials" → enter the client ID and secret → authorise the Chat scopes you need → exchange the authorisation code for tokens.

    ![OAuth Playground](https://raw.githubusercontent.com/ballerina-platform/module-ballerinax-googleapis.chat/main/docs/setup/resources/oauth-playground.png)

#### Option C — Bearer token (for quick tests)

For short-lived experiments you can use a Google access token directly:

```bash
gcloud auth print-access-token
```

> **Note:** Google access tokens expire in roughly one hour. Bearer-token auth is best for short-lived processes (CI jobs, scripts, manual tests). For long-running services, use service account or OAuth 2.0 — both auto-refresh tokens.

## Quickstart

To use the `googleapis.chat` connector in your Ballerina application, modify the `.bal` file as follows.

### Step 1: Import the module

```ballerina
import ballerinax/googleapis.chat;
```

### Step 2 (Client): Initialise a Chat client

Use this if your app only calls the Chat REST API (no event handling). Create a `chat:ConnectionConfig` with the credentials obtained during setup.

```ballerina
configurable chat:OAuth2Config oauthAuth = ?;

final chat:Client chatClient = check new ({auth: oauthAuth});
```

### Step 3 (Client): Invoke connector operations

```ballerina
// List spaces the app has access to.
chat:ListSpacesResponse spaces = check chatClient->/spaces;

// Send a message to a space.
chat:Message sent = check chatClient->/spaces/["AAAA1234"]/messages.post({
    text: "Hello from Ballerina!"
});
```

### Step 2 (Listener): Initialise a Chat listener

Use this if your app needs to handle interaction events from Google Chat (messages, card clicks, slash commands, etc.). The listener exposes an HTTP endpoint that Google Chat POSTs events to; it provides an internal Chat API client used by the injected `chat:Caller` — no separate client needed for replies.

```ballerina
listener chat:Listener chatListener = new (8000, {
    auth: {path: "./service-account-key.json"}
});

@chat:ServiceConfig {
    endpointUrl: "https://<your-subdomain>.ngrok-free.app"
}
service chat:ChatService on chatListener {

    remote function onMessage(chat:ChatEvent event, chat:Caller caller) returns error? {
        _ = check caller->reply("Echo: " + (event.message?.text ?: ""));
    }
}
```

The `endpointUrl` must exactly match the **HTTP endpoint URL** configured in your Chat app (Setup Step 4). The listener uses it to validate the `aud` claim of the incoming Google-signed bearer token. If you configured the **Authentication audience** as your project number instead, use `projectNumber: "<your-project-number>"` in the annotation in place of `endpointUrl`.

### Step 3 (Listener): Implement handlers

`chat:ChatService` exposes one optional `remote function` per Chat event type. Implement only the ones you need:

| Function              | Triggered by                                                     |
| --------------------- | ---------------------------------------------------------------- |
| `onMessage`           | A user sends a message, @mentions the app, or invokes a slash command. |
| `onAddedToSpace`      | The app is added to a space.                                     |
| `onRemovedFromSpace`  | The app is removed from a space.                                 |
| `onCardClicked`       | A user clicks a button or interactive element on a card.         |
| `onSubmitForm`        | A user submits a dialog or form.                                 |
| `onAppHome`           | A user opens the app's home page.                                |
| `onWidgetUpdated`     | A widget requests an autocomplete or similar update.             |

Each handler receives the `chat:ChatEvent` and (optionally) a `chat:Caller` pre-configured with the event's space context. Use the caller to `respond` (synchronously, within the event window) or to call Chat APIs asynchronously (`sendMessage`, `updateMessage`, etc.).

### Step 4: Run the Ballerina application

```bash
bal run
```

In a separate terminal, expose the listener to Google Chat with ngrok (see Setup Step 3):

```bash
ngrok http 8000
```

## Examples

The `googleapis.chat` connector provides practical examples illustrating usage in various scenarios. Explore these [examples](https://github.com/ballerina-platform/module-ballerinax-googleapis.chat/tree/main/ballerina/examples).

1. [HTTP endpoint listener with service account](https://github.com/ballerina-platform/module-ballerinax-googleapis.chat/tree/main/ballerina/examples/http_service_account) — Receive Chat events over HTTP with Google-signed bearer-token verification; reply via the injected `chat:Caller`.

2. [Echo uploaded image](https://github.com/ballerina-platform/module-ballerinax-googleapis.chat/tree/main/ballerina/examples/echo_uploaded_image) — Demonstrates attachment download and upload using the Chat client (requires OAuth user scopes).
