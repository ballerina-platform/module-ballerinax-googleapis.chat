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

import ballerina/test;

const int RESPONSE_WAIT_SECONDS = 5;

isolated function awaitPayload(ResponseFuture respFut) returns map<anydata>|error =>
    respFut.waitFor(RESPONSE_WAIT_SECONDS).ensureType();

@test:Config {}
function testMessageCallerRespond() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    check caller->respond({text: "hello"});
    map<anydata> result = check awaitPayload(respFut);
    test:assertEquals(result["text"], "hello");
}

@test:Config {}
function testMessageCallerRespondDefaultEmpty() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    check caller->respond();
    map<anydata> result = check awaitPayload(respFut);
    test:assertEquals(result, {});
}

@test:Config {}
function testMessageCallerDoubleRespond() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    check caller->respond({text: "first"});
    error? second = caller->respond({text: "second"});
    test:assertTrue(second is DispatchError);
}

@test:Config {}
function testMessageCallerSendMessage() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    Message sent = check caller->sendMessage({text: "async"});
    test:assertEquals(sent.text, "created");
}

@test:Config {}
function testMessageCallerUpdateMessage() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    Message updated = check caller->updateMessage(
        {name: "spaces/" + TEST_SPACE + "/messages/" + TEST_MESSAGE, text: "edit"}, updateMask = "text");
    test:assertEquals(updated.text, "updated");
}

@test:Config {}
function testMessageCallerUpdateMessageAllowMissing() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    Message updated = check caller->updateMessage(
        {name: "spaces/" + TEST_SPACE + "/messages/" + TEST_MESSAGE, text: "edit"},
        updateMask = "text", allowMissing = true);
    test:assertEquals(updated.text, "updated");
}

@test:Config {}
function testMessageCallerDeleteMessage() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    check caller->deleteMessage({name: "spaces/" + TEST_SPACE + "/messages/" + TEST_MESSAGE});
}

@test:Config {}
function testMessageCallerGetSpace() returns error? {
    ResponseFuture respFut = new;
    MessageCaller caller = new (mockClient, TEST_SPACE, respFut);
    Space space = check caller->getSpace();
    test:assertEquals(space.name, "spaces/" + TEST_SPACE);
}

// ─── CardClickedCaller ─────────────────────────────────────────────────────────────

@test:Config {}
function testCardClickedCallerRespondMessage() returns error? {
    ResponseFuture respFut = new;
    CardClickedCaller caller = new (mockClient, TEST_SPACE, respFut);
    check caller->respond(<Message>{actionResponse: {'type: UPDATE_MESSAGE}, text: "updated card"});
    map<anydata> result = check awaitPayload(respFut);
    test:assertEquals(result["text"], "updated card");
}

@test:Config {}
function testCardClickedCallerRespondCardWraps() returns error? {
    ResponseFuture respFut = new;
    CardClickedCaller caller = new (mockClient, TEST_SPACE, respFut);
    Card card = {sections: [{widgets: [{textParagraph: {text: "hi"}}]}]};
    check caller->respond(card);
    map<anydata> result = check awaitPayload(respFut);
    RenderActionsResponse wrapped = check result.cloneWithType();
    test:assertTrue(wrapped.renderActions.action.navigations is Navigation[]);
    test:assertTrue(wrapped.renderActions.action.navigations[0].updateCard is Card);
}

@test:Config {}
function testCardClickedCallerDoubleRespond() returns error? {
    ResponseFuture respFut = new;
    CardClickedCaller caller = new (mockClient, TEST_SPACE, respFut);
    check caller->respond(<Message>{text: "first"});
    error? second = caller->respond(<Message>{text: "second"});
    test:assertTrue(second is DispatchError);
}

@test:Config {}
function testCardClickedCallerSendMessage() returns error? {
    ResponseFuture respFut = new;
    CardClickedCaller caller = new (mockClient, TEST_SPACE, respFut);
    Message sent = check caller->sendMessage({text: "x"});
    test:assertEquals(sent.text, "created");
}

@test:Config {}
function testCardClickedCallerGetSpace() returns error? {
    ResponseFuture respFut = new;
    CardClickedCaller caller = new (mockClient, TEST_SPACE, respFut);
    Space space = check caller->getSpace();
    test:assertEquals(space.name, "spaces/" + TEST_SPACE);
}

// ─── AppHomeCaller ──────────────────────────────────────────────────────────────────

@test:Config {}
function testAppHomeCallerRespondWrapsPushCard() returns error? {
    ResponseFuture respFut = new;
    AppHomeCaller caller = new (respFut);
    Card card = {sections: [{widgets: [{textParagraph: {text: "home"}}]}]};
    check caller->respond(card);
    map<anydata> result = check awaitPayload(respFut);
    AppHomeResponse wrapped = check result.cloneWithType();
    test:assertTrue(wrapped.action.navigations is Navigation[]);
    test:assertTrue(wrapped.action.navigations[0].pushCard is Card);
}

@test:Config {}
function testAppHomeCallerDoubleRespond() returns error? {
    ResponseFuture respFut = new;
    AppHomeCaller caller = new (respFut);
    check caller->respond();
    error? second = caller->respond();
    test:assertTrue(second is DispatchError);
}

// ─── SubmitFormCaller ──────────────────────────────────────────────────────────────

@test:Config {}
function testSubmitFormCallerRespondWrapsUpdateCard() returns error? {
    ResponseFuture respFut = new;
    SubmitFormCaller caller = new (respFut);
    Card card = {sections: [{widgets: [{textParagraph: {text: "submitted"}}]}]};
    check caller->respond(card);
    map<anydata> result = check awaitPayload(respFut);
    RenderActionsResponse wrapped = check result.cloneWithType();
    test:assertTrue(wrapped.renderActions.action.navigations is Navigation[]);
    test:assertTrue(wrapped.renderActions.action.navigations[0].updateCard is Card);
}

@test:Config {}
function testSubmitFormCallerDoubleRespond() returns error? {
    ResponseFuture respFut = new;
    SubmitFormCaller caller = new (respFut);
    check caller->respond();
    error? second = caller->respond();
    test:assertTrue(second is DispatchError);
}

// ─── WidgetUpdatedCaller ───────────────────────────────────────────────────────────

@test:Config {}
function testWidgetUpdatedCallerRespond() returns error? {
    ResponseFuture respFut = new;
    WidgetUpdatedCaller caller = new (respFut);
    check caller->respond({actionResponse: {'type: UPDATE_WIDGET}});
    map<anydata> result = check awaitPayload(respFut);
    test:assertTrue(result.hasKey("actionResponse"));
}

@test:Config {}
function testWidgetUpdatedCallerDoubleRespond() returns error? {
    ResponseFuture respFut = new;
    WidgetUpdatedCaller caller = new (respFut);
    check caller->respond();
    error? second = caller->respond();
    test:assertTrue(second is DispatchError);
}

// ─── resolveMessageId ──────────────────────────────────────────────────────────────

@test:Config {}
function testResolveMessageIdFullName() returns error? {
    string id = check resolveMessageId("spaces/AAA/messages/MSG123");
    test:assertEquals(id, "MSG123");
}

@test:Config {}
function testResolveMessageIdBareId() returns error? {
    string id = check resolveMessageId("MSG123");
    test:assertEquals(id, "MSG123");
}

@test:Config {}
function testResolveMessageIdEmpty() {
    string|error id = resolveMessageId("");
    test:assertTrue(id is ClientError);
}

@test:Config {}
function testResolveMessageIdNil() {
    string|error id = resolveMessageId(());
    test:assertTrue(id is ClientError);
}

@test:Config {}
function testResolveMessageIdTrailingSlash() {
    string|error id = resolveMessageId("spaces/AAA/messages/");
    test:assertTrue(id is ClientError);
}
