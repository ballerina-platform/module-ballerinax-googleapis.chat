# Echo bot

A minimal Google Chat app that replies to every message with the same text it received. It demonstrates the listener's HTTP delivery mode, Google-signed bearer-token verification, and replying through the injected `chat:MessageCaller`.

## Prerequisites

### 1. Set up the Google Chat API

Follow the connector [setup guide](https://github.com/ballerina-platform/module-ballerinax-googleapis.chat#setup-guide) to:

- Create a Google Cloud project and enable the Google Chat API.
- Create a **service account** and download its JSON key file (Option A in the setup guide).
- Configure the Chat app with **Connection settings → HTTP endpoint URL** and an **Authentication audience** of *HTTP endpoint URL*.

### 2. Expose the listener

Google Chat must reach the listener over a public HTTPS URL. For local development:

```bash
ngrok http 8000
```

Use the printed `https://<sub>.ngrok-free.app` URL as both the **HTTP endpoint URL** in the Chat app configuration and the `endpointUrl` below.

### 3. Configuration

Create a `Config.toml` file in this directory:

```toml
endpointUrl = "https://<your-subdomain>.ngrok-free.app"
# port = 8000   # optional, defaults to 8000

[serviceAccountAuth]
path = "./service-account-key.json"
```

## Run the example

```bash
bal run
```

Send the app a message in Google Chat — it replies with `You said: <your message>`.
