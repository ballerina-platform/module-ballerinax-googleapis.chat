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
import ballerina/test;

// ═══════════════════════════════════════════════════════════════════════════════
// Dispatch routing tests.
//
// `DispatcherService.dispatch(ChatEvent)` runs the registered handler on a virtual
// thread (native dispatch) and blocks on the ResponseFuture until the handler calls
// respond(). Events are loaded from captured fixtures, normalized, decoded to
// ChatEvent, and dispatched against a service that responds for every event type.
// ═══════════════════════════════════════════════════════════════════════════════

// A ChatService that acknowledges every event so dispatch() returns promptly.
service class RespondingChatService {
    *ChatService;

    remote function onMessage(MessageEvent event, MessageCaller caller) returns error? {
        check caller->respond({text: "ack:message"});
    }

    remote function onAddedToSpace(ChatEvent event, MessageCaller caller) returns error? {
        check caller->respond({text: "ack:added"});
    }

    remote function onRemovedFromSpace(ChatEvent event) returns error? {
    }

    remote function onCardClicked(ChatEvent event, CardClickedCaller caller) returns error? {
        check caller->respond(<Message>{text: "ack:card"});
    }

    remote function onWidgetUpdated(ChatEvent event, WidgetUpdatedCaller caller) returns error? {
        check caller->respond({text: "ack:widget"});
    }

    remote function onAppCommand(ChatEvent event, MessageCaller caller) returns error? {
        check caller->respond({text: "ack:command"});
    }

    remote function onAppHome(ChatEvent event, AppHomeCaller caller) returns error? {
        check caller->respond({sections: []});
    }

    remote function onSubmitForm(ChatEvent event, SubmitFormCaller caller) returns error? {
        check caller->respond({sections: []});
    }
}

// Builds a dispatcher with the responding service registered.
function newRespondingDispatcher() returns DispatcherService|error {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new (testClient);
    RespondingChatService svc = new ();
    check dispatcher.addServiceRef("ChatService", svc);
    return dispatcher;
}

// Loads a fixture, normalizes it, and decodes it to a ChatEvent.
function loadEvent(string fixture) returns ChatEvent|error {
    json raw = check io:fileReadJson("tests/resources/events/" + fixture);
    json normalized = check normalizeEventPayload(raw);
    return normalized.cloneWithType(ChatEvent);
}

@test:Config {}
function testDispatchMessage() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("message.json"));
    test:assertEquals(response["text"], "ack:message");
}

@test:Config {}
function testDispatchAddedToSpace() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("added_to_space.json"));
    test:assertEquals(response["text"], "ack:added");
}

@test:Config {}
function testDispatchCardClicked() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("card_clicked.json"));
    test:assertEquals(response["text"], "ack:card");
}

@test:Config {}
function testDispatchAppCommand() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("app_command.json"));
    test:assertEquals(response["text"], "ack:command");
}

@test:Config {}
function testDispatchWidgetUpdated() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("widget_updated.json"));
    test:assertEquals(response["text"], "ack:widget");
}

@test:Config {}
function testDispatchAppHomeWrapsCard() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("app_home.json"));
    // AppHomeCaller wraps the card in `{ action: { navigations: [{ pushCard: ... }] } }`.
    test:assertTrue(response.hasKey("action"));
}

@test:Config {}
function testDispatchSubmitFormWrapsCard() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("submit_form.json"));
    // SubmitFormCaller wraps the card in `{ renderActions: { ... } }`.
    test:assertTrue(response.hasKey("renderActions"));
}

@test:Config {}
function testDispatchRemovedFromSpaceReturnsEmpty() returns error? {
    DispatcherService dispatcher = check newRespondingDispatcher();
    map<anydata> response = dispatcher.dispatch(check loadEvent("removed_from_space.json"));
    // Fire-and-forget — no caller, immediate empty reply.
    test:assertEquals(response, {});
}

@test:Config {}
function testDispatchNoServiceRegisteredReturnsEmpty() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new (testClient);
    map<anydata> response = dispatcher.dispatch(check loadEvent("message.json"));
    test:assertEquals(response, {});
}
