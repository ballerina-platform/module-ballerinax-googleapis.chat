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

import ballerina/io;
import ballerinax/googleapis.chat;

// ---------------------------------------------------------------------------
// Echo bot
//
// A minimal Google Chat app that replies to every message with the same text.
// Google Chat delivers interaction events over HTTP; the listener verifies the
// Google-signed bearer token on each request before dispatching to onMessage.
//
// Configure the values below in Config.toml (see this example's README), then:
//   bal run
//   ngrok http 8000   # in another terminal, to expose the listener
// and set the printed HTTPS URL as the HTTP endpoint URL in your Chat app.
// ---------------------------------------------------------------------------

// Path to the service account JSON key file used to call the Chat API when
// replying. See the connector setup guide for how to create and download it.
configurable chat:ServiceAccountFileConfig serviceAccountAuth = ?;

// The public HTTPS URL of this listener, exactly as entered in the
// "HTTP endpoint URL" field of the Chat app configuration. Used to validate
// the `aud` claim of incoming Google-signed bearer tokens.
configurable string endpointUrl = ?;

// Port the listener binds to locally.
configurable int port = 8000;

listener chat:Listener chatListener = new (port, {auth: serviceAccountAuth});

@chat:ServiceConfig {
    endpointUrl: endpointUrl
}
service chat:ChatService on chatListener {

    // Triggered when a user sends a message to the app (DM or @mention).
    // The MessageCaller is injected automatically and is pre-configured with
    // the space context, so replying is a single respond() call.
    remote function onMessage(chat:MessageEvent event, chat:MessageCaller caller) returns error? {
        string text = event.message.text ?: "";
        io:println("Received message: ", text);
        check caller->respond({text: "Echo: " + text});
    }
}
