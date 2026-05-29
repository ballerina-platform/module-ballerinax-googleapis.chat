# Examples

The `googleapis.chat` connector provides practical examples illustrating usage in various scenarios.

1. [Echo bot](echo-bot) — A minimal Google Chat app that replies to every message with the same text, demonstrating the listener's HTTP delivery mode and replying via the injected `chat:MessageCaller`.

## Prerequisites

1. Follow the connector [setup guide](https://github.com/ballerina-platform/module-ballerinax-googleapis.chat#setup-guide) to create a Google Cloud project, enable the Google Chat API, configure the Chat app, and obtain credentials.

2. For each example, create a `Config.toml` file in the example directory with the required configuration (see the example's own README).

## Running an example

Execute the following commands to build and run an example from its directory:

```bash
bal build
bal run
```
