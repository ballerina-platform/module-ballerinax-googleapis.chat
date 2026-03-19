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

package io.ballerina.lib.googleapis.chat;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * A synchronization primitive for bridging asynchronous handler execution with the synchronous HTTP response
 * requirement.
 * <p>
 * The HTTP resource function creates a {@code ResponseFuture} and passes it (via the Caller) to the handler running on
 * a virtual thread. When the handler calls {@code respond()}, the Caller sets the response payload on this future via
 * {@code complete()}. The resource function blocks on {@code waitForResponse()} until the future completes or a timeout
 * expires.
 * <p>
 * This approach allows the handler to continue running after calling {@code respond()} — only the response payload is
 * synchronized, not the handler's full lifecycle.
 *
 * @since 0.1.0
 */
public final class ResponseFuture {

    private final CompletableFuture<Object> future = new CompletableFuture<>();

    /**
     * Called by the Caller's {@code respond()} method to set the response payload. This unblocks the resource function
     * waiting on {@code waitForResponse()}.
     *
     * @param payload the JSON response payload (Ballerina json value)
     */
    public void complete(Object payload) {
        future.complete(payload);
    }

    /**
     * Called by the dispatcher's resource function to wait for the handler to call {@code respond()}. Blocks the
     * calling strand until the response is available or the timeout expires.
     *
     * @param timeoutSeconds the maximum time to wait in seconds
     * @return the response payload, or {@code null} if the timeout expired
     */
    public Object waitForResponse(long timeoutSeconds) {
        try {
            return future.get(timeoutSeconds, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            return null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Checks whether the response has already been set.
     *
     * @return {@code true} if {@code complete()} has been called
     */
    public boolean isDone() {
        return future.isDone();
    }

    // ── Static methods callable from Ballerina via native interop ────────────

    /**
     * Creates a new {@code ResponseFuture} instance. Called from Ballerina:
     * {@code ResponseFuture future = createResponseFuture();}
     *
     * @return a new ResponseFuture handle
     */
    public static ResponseFuture createResponseFuture() {
        return new ResponseFuture();
    }

    /**
     * Sets the response payload on the given future, unblocking the waiting resource function. Called from the Caller's
     * {@code respond()} method in Ballerina.
     *
     * @param future  the ResponseFuture handle
     * @param payload the JSON response payload
     */
    public static void completeFuture(ResponseFuture future, Object payload) {
        future.complete(payload);
    }

    /**
     * Blocks until the response is available or the timeout expires. Called from the dispatcher's resource function in
     * Ballerina.
     *
     * @param future         the ResponseFuture handle
     * @param timeoutSeconds the maximum time to wait
     * @return the response payload, or {@code null} if timed out
     */
    public static Object waitForResponseStatic(ResponseFuture future, long timeoutSeconds) {
        return future.waitForResponse(timeoutSeconds);
    }
}
