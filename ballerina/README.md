## Overview

[Google Chat](https://workspace.google.com/products/chat/) is a communication platform from Google, designed for teams and businesses as part of Google Workspace.

The Ballerina Google Chat connector offers APIs to connect and interact with the [Google Chat REST API](https://developers.google.com/workspace/chat/api/reference/rest).

## Setup guide

<!-- Add setup guide here -->

## Quickstart

To use the `googleapis.chat` connector in your Ballerina application, modify the `.bal` file as follows:

### Step 1: Import the module

Import the `googleapis.chat` module.

```ballerina
import ballerinax/googleapis.chat;
```

### Step 2: Instantiate a new connector

Create a `chat:ConnectionConfig` with the required credentials and initialize the connector with it.

```ballerina
chat:Client chatClient = check new ({
    auth: {
        token: "<your-access-token>"
    }
});
```

### Step 3: Invoke the connector operation

Now, utilize the available connector operations.

### Step 4: Run the Ballerina application

```bash
bal run
```

## Examples

The `googleapis.chat` connector provides practical examples illustrating usage in various scenarios.

<!-- Add examples here -->
