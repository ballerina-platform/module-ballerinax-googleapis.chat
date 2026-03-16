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

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Module;

/**
 * Utility class to hold the Ballerina module reference for the Google Chat package.
 * <p>
 * The module reference is captured during Ballerina module initialization via {@code init.bal -> setModule()} and is
 * used by the {@link ChatEventDispatcher} to create {@code Caller} BObjects using {@code ValueCreator}.
 *
 * @since 0.1.0
 */
public final class ModuleUtils {

    private static volatile Module chatModule = null;

    private ModuleUtils() {
    }

    /**
     * Called from Ballerina {@code init.bal} during module initialization to capture the current module reference.
     *
     * @param env the Ballerina runtime environment
     */
    public static void setModule(Environment env) {
        chatModule = env.getCurrentModule();
    }

    /**
     * Returns the Google Chat Ballerina module reference.
     *
     * @return the module reference
     */
    public static Module getModule() {
        return chatModule;
    }
}
