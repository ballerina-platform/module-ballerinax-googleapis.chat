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

final http:BearerTokenConfig listenerAuth = {token: "test-token"};

listener Listener gracefulListener = new (21092, auth = listenerAuth);
listener Listener immediateListener = new (21093, auth = listenerAuth);

@ServiceConfig {
    endpointUrl: "https://my-app.example.com"
}
service ChatService on gracefulListener {
    remote function onMessage(MessageEvent event, MessageCaller caller) returns error? {
        check caller->respond({text: "hi"});
    }
}

@ServiceConfig {
    endpointUrl: "https://my-app.example.com"
}
service ChatService on immediateListener {
    remote function onMessage(MessageEvent event, MessageCaller caller) returns error? {
        check caller->respond({text: "hi"});
    }
}

// A ChatService without the @ServiceConfig annotation — attach() must reject it.
isolated service class UnannotatedChatService {
    *ChatService;

    remote function onMessage(MessageEvent event, MessageCaller caller) returns error? {
    }
}

// Requests without a valid Google-signed token must be rejected with 401. This drives
// the auto-started `gracefulListener` through the dispatcher resource function.
@test:Config {}
function testListenerRejectsUnauthenticatedRequests() returns error? {
    http:Client ep = check new ("http://localhost:21092");

    // No Authorization header → 401.
    http:Response noAuth = check ep->post("/", {'type: "MESSAGE"});
    test:assertEquals(noAuth.statusCode, 401);

    // Malformed bearer token → token verification fails → 401.
    http:Response badAuth = check ep->post("/", {'type: "MESSAGE"},
            {"Authorization": "Bearer not-a-valid-jwt"});
    test:assertEquals(badAuth.statusCode, 401);
}

@test:Config {}
function testListenerStartWithoutServiceFails() returns error? {
    Listener chatListener = check new (21090, auth = listenerAuth);
    error? result = chatListener.'start();
    test:assertTrue(result is ListenerError);
    if result is ListenerError {
        test:assertTrue(result.message().includes("No ChatService"));
    }
}

@test:Config {}
function testListenerAttachWithoutAnnotationFails() returns error? {
    Listener chatListener = check new (21091, auth = listenerAuth);
    UnannotatedChatService svc = new;
    error? result = chatListener.attach(svc, ());
    test:assertTrue(result is ListenerError);
    if result is ListenerError {
        test:assertTrue(result.message().includes("@chat:ServiceConfig"));
    }
}

@test:Config {}
function testListenerDetachUnattachedFails() returns error? {
    Listener chatListener = check new (21094, auth = listenerAuth);
    UnannotatedChatService svc = new;
    error? result = chatListener.detach(svc);
    test:assertTrue(result is ListenerError);
}

@test:AfterSuite {}
function stopListeners() returns error? {
    check gracefulListener.gracefulStop();
    check immediateListener.immediateStop();
}
