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

import ballerina/http;
import ballerina/test;

// ═══════════════════════════════════════════════════════════════════════════════
// Dispatcher Service Unit Tests
// ═══════════════════════════════════════════════════════════════════════════════

// Helper to create a test Client with a dummy bearer token (never actually called).
function createTestClient() returns Client|error {
    return new ({auth: <http:BearerTokenConfig>{token: "test-token"}});
}

// Test that DispatcherService correctly initializes with a subscription resource.
@test:Config {}
function testDispatcherServiceInit() returns error? {
    Client testClient = check createTestClient();
    DispatcherService _ = new ("projects/test-project/subscriptions/test-sub", testClient);
    // If init succeeds without error, the test passes.
    test:assertTrue(true);
}

// Test adding a service ref to the dispatcher.
@test:Config {}
function testDispatcherAddServiceRef() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("projects/test-project/subscriptions/test-sub", testClient);

    MockChatService mockService = new ();
    check dispatcher.addServiceRef("ChatService", mockService);
    // If add succeeds without error, the test passes.
    test:assertTrue(true);
}

// Test that adding a duplicate service ref returns an error.
@test:Config {}
function testDispatcherAddDuplicateServiceRef() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("projects/test-project/subscriptions/test-sub", testClient);

    MockChatService mockService = new ();
    check dispatcher.addServiceRef("ChatService", mockService);

    // Adding the same service type again should error.
    error? result = dispatcher.addServiceRef("ChatService", mockService);
    test:assertTrue(result is error);
    if result is error {
        test:assertTrue(result.message().includes("already been attached"));
    }
}

// Test removing a service ref from the dispatcher.
@test:Config {}
function testDispatcherRemoveServiceRef() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("projects/test-project/subscriptions/test-sub", testClient);

    MockChatService mockService = new ();
    check dispatcher.addServiceRef("ChatService", mockService);
    check dispatcher.removeServiceRef("ChatService");
    // If remove succeeds without error, the test passes.
    test:assertTrue(true);
}

// Test that removing a non-existent service ref returns an error.
@test:Config {}
function testDispatcherRemoveNonExistentServiceRef() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("projects/test-project/subscriptions/test-sub", testClient);

    error? result = dispatcher.removeServiceRef("ChatService");
    test:assertTrue(result is error);
    if result is error {
        test:assertTrue(result.message().includes("has not been attached"));
    }
}

// Test that re-adding a service after removal works.
@test:Config {}
function testDispatcherReAddServiceRef() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("projects/test-project/subscriptions/test-sub", testClient);

    MockChatService mockService = new ();
    check dispatcher.addServiceRef("ChatService", mockService);
    check dispatcher.removeServiceRef("ChatService");

    // Should be able to add again after removal.
    check dispatcher.addServiceRef("ChatService", mockService);
    test:assertTrue(true);
}

// Test dispatching with no service attached (should not error, silently returns).
@test:Config {}
function testDispatchWithNoServiceAttached() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("projects/test-project/subscriptions/test-sub", testClient);

    ChatEvent event = {
        'type: MESSAGE,
        message: {text: "Hello"}
    };

    // Should not error, just silently return since no service is registered.
    check dispatcher.dispatch(event);
    test:assertTrue(true);
}

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP Mode Dispatcher Tests
// ═══════════════════════════════════════════════════════════════════════════════

// Test that DispatcherService initializes correctly in HTTP endpoint URL mode.
@test:Config {}
function testDispatcherServiceInitHttpMode() returns error? {
    Client testClient = check createTestClient();
    HttpEndpointUrlConfig httpCfg = {
        endpointUrl: "https://my-app.example.com"
    };
    DispatcherService _ = new ("", testClient, httpCfg);
    test:assertTrue(true);
}

// Test that setHttpConfig accepts an HttpEndpointUrlConfig.
@test:Config {}
function testDispatcherSetHttpConfig() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("", testClient);

    HttpEndpointUrlConfig httpCfg = {
        endpointUrl: "https://my-app.example.com"
    };
    dispatcher.setHttpConfig(httpCfg);
    // No error means the config was accepted.
    test:assertTrue(true);
}

// Test that setHttpConfig accepts a ProjectNumberConfig.
@test:Config {}
function testDispatcherSetHttpConfigProjectNumber() returns error? {
    Client testClient = check createTestClient();
    DispatcherService dispatcher = new ("", testClient);

    ProjectNumberConfig httpCfg = {
        projectNumber: "1234567890"
    };
    dispatcher.setHttpConfig(httpCfg);
    test:assertTrue(true);
}

// Test dispatching a MESSAGE event in HTTP mode (no service registered).
@test:Config {}
function testHttpModeDispatchWithNoServiceAttached() returns error? {
    Client testClient = check createTestClient();
    HttpEndpointUrlConfig httpCfg = {
        endpointUrl: "https://my-app.example.com"
    };
    DispatcherService dispatcher = new ("", testClient, httpCfg);

    ChatEvent event = {
        'type: MESSAGE,
        message: {text: "Hello from HTTP mode"}
    };
    // Should not error — silently returns when no service is registered.
    check dispatcher.dispatch(event);
    test:assertTrue(true);
}

// Test that extractBearerToken correctly parses a well-formed Authorization header.
@test:Config {}
function testExtractBearerTokenValid() returns error? {
    http:Request req = new;
    req.setHeader("Authorization", "Bearer test-token-value");
    string token = check extractBearerToken(req);
    test:assertEquals(token, "test-token-value");
}

// Test that extractBearerToken returns an error when Authorization header is absent.
@test:Config {}
function testExtractBearerTokenMissingHeader() {
    http:Request req = new;
    string|AuthenticationError result = extractBearerToken(req);
    test:assertTrue(result is AuthenticationError);
    if result is AuthenticationError {
        test:assertTrue(result.message().includes("Authorization"));
    }
}

// Test that extractBearerToken returns an error for a non-Bearer scheme.
@test:Config {}
function testExtractBearerTokenWrongScheme() {
    http:Request req = new;
    req.setHeader("Authorization", "Basic dXNlcjpwYXNz");
    string|AuthenticationError result = extractBearerToken(req);
    test:assertTrue(result is AuthenticationError);
}

// Test that extractBearerToken returns an error when the token value is empty.
@test:Config {}
function testExtractBearerTokenEmptyValue() {
    http:Request req = new;
    req.setHeader("Authorization", "Bearer ");
    string|AuthenticationError result = extractBearerToken(req);
    test:assertTrue(result is AuthenticationError);
}

// Note: Full verifyChatBearerToken tests (ID Token and Project Number JWT)
// require a real Google-signed token and cannot be run as offline unit tests.
// ID token verification accepts both `accounts.google.com` and
// `https://accounts.google.com` issuers. These are covered by integration tests.

// Note: Dispatch tests that verify actual remote function invocation on the
// MockChatService require the native Java dispatcher to be available at
// runtime. Testing the full dispatch flow requires integration tests with
// a running HTTP listener and Pub/Sub push simulation.

// ═══════════════════════════════════════════════════════════════════════════════
// Mock ChatService for Testing
// ═══════════════════════════════════════════════════════════════════════════════

# A mock ChatService implementation for verifying service ref management.
service class MockChatService {
    *ChatService;

    boolean messageReceived = false;
    boolean addedToSpaceReceived = false;
    boolean removedFromSpaceReceived = false;
    boolean cardClickedReceived = false;
    boolean appHomeReceived = false;
    boolean submitFormReceived = false;

    remote function onMessage(ChatEvent event) returns error? {
        self.messageReceived = true;
    }

    remote function onAddedToSpace(ChatEvent event) returns error? {
        self.addedToSpaceReceived = true;
    }

    remote function onRemovedFromSpace(ChatEvent event) returns error? {
        self.removedFromSpaceReceived = true;
    }

    remote function onCardClicked(ChatEvent event) returns error? {
        self.cardClickedReceived = true;
    }

    remote function onAppHome(ChatEvent event) returns error? {
        self.appHomeReceived = true;
    }

    remote function onSubmitForm(ChatEvent event) returns error? {
        self.submitFormReceived = true;
    }
}
