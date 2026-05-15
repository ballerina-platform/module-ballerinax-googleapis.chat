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

import ballerina/jballerina.java;

# Synchronization primitive that bridges a handler running on a virtual thread
# with the dispatcher's HTTP resource function. The dispatcher creates an
# instance, hands it to the event-specific Caller, then blocks on `waitFor`
# until the handler calls `complete` (via `Caller->respond`) or the timeout
# expires.
#
# This Ballerina class wraps a Java `CompletableFuture`. The `handle` is
# confined to this file so that the Caller classes and the dispatcher can
# refer to the future by a Ballerina type instead of the raw JVM reference.
isolated class ResponseFuture {
    private final handle jFuture;

    isolated function init() {
        self.jFuture = jCreateResponseFuture();
    }

    # Signals the future with the response payload, unblocking the dispatcher.
    #
    # + payload - The JSON response payload to deliver
    isolated function complete(json payload) {
        jCompleteFuture(self.jFuture, payload);
    }

    # Blocks until `complete` is called or the timeout expires.
    #
    # + timeoutSeconds - Maximum seconds to wait before returning `()`
    # + return - The JSON payload set by `complete`, or `()` on timeout
    isolated function waitFor(int timeoutSeconds) returns json {
        return jWaitForResponse(self.jFuture, timeoutSeconds);
    }
}

isolated function jCreateResponseFuture() returns handle = @java:Method {
    name: "createResponseFuture",
    'class: "io.ballerina.lib.googleapis.chat.ResponseFuture"
} external;

isolated function jCompleteFuture(handle jFuture, json payload) = @java:Method {
    name: "completeFuture",
    'class: "io.ballerina.lib.googleapis.chat.ResponseFuture"
} external;

isolated function jWaitForResponse(handle jFuture, int timeoutSeconds) returns json = @java:Method {
    name: "waitForResponseStatic",
    'class: "io.ballerina.lib.googleapis.chat.ResponseFuture"
} external;