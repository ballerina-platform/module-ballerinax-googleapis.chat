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
// normalizeEventPayload — lifts the Workspace Add-ons APP_HOME / SUBMIT_FORM shape
// (nested `chat.*` + `commonEventObject`) to the flat `ChatEvent` structure.
// ═══════════════════════════════════════════════════════════════════════════════

@test:Config {}
function testNormalizeAppHomePayload() returns error? {
    json raw = check io:fileReadJson("tests/resources/events/app_home.json");
    json normalized = check normalizeEventPayload(raw);
    map<json> result = check normalized.cloneWithType();

    // chat.* lifted to root
    test:assertEquals(result["type"], "APP_HOME");
    test:assertTrue(result["user"] is map<json>);
    test:assertTrue(result["space"] is map<json>);
    // commonEventObject → common
    test:assertTrue(result["common"] is map<json>);
    // wrapper fields removed
    test:assertFalse(result.hasKey("chat"));
    test:assertFalse(result.hasKey("commonEventObject"));
    test:assertFalse(result.hasKey("authorizationEventObject"));
}

@test:Config {}
function testNormalizeSubmitFormPayloadDecodesToChatEvent() returns error? {
    json raw = check io:fileReadJson("tests/resources/events/submit_form.json");
    json normalized = check normalizeEventPayload(raw);
    ChatEvent event = check normalized.cloneWithType();
    test:assertEquals(event.'type, SUBMIT_FORM);
}

@test:Config {}
function testNormalizeFlatPayloadUnchanged() returns error? {
    json raw = check io:fileReadJson("tests/resources/events/message.json");
    json normalized = check normalizeEventPayload(raw);
    // A flat payload (no `chat` wrapper) is returned as-is.
    test:assertEquals(normalized, raw);
}
