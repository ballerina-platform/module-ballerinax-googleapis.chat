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

package io.ballerina.lib.googlechat;

import io.ballerina.runtime.api.Environment;
import io.ballerina.runtime.api.Runtime;
import io.ballerina.runtime.api.concurrent.StrandMetadata;
import io.ballerina.runtime.api.creators.ErrorCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.MethodType;
import io.ballerina.runtime.api.types.ObjectType;
import io.ballerina.runtime.api.types.Parameter;
import io.ballerina.runtime.api.types.RemoteMethodType;
import io.ballerina.runtime.api.types.ServiceType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.types.TypeTags;
import io.ballerina.runtime.api.types.UnionType;
import io.ballerina.runtime.api.utils.StringUtils;
import io.ballerina.runtime.api.utils.TypeUtils;
import io.ballerina.runtime.api.values.BError;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;

import java.io.PrintStream;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Native dispatcher for Google Chat events. Inspects the remote function signature on the user's {@code ChatService}
 * and injects both the {@code ChatEvent} record and (optionally) a {@code Caller} client object.
 * <p>
 * This replaces the generic {@code asyncapi.native.handler:NativeHandler} which only supports passing a single event
 * argument.
 *
 * @since 0.1.0
 */
public final class ChatEventDispatcher {

    private static final PrintStream ERR_OUT = System.err;
    private static final String CHAT_EVENT_RECORD = "ChatEvent";
    private static final String CALLER_OBJECT = "Caller";
    private static final String ORG_NAME = "ballerinax";
    private static final String MODULE_NAME = "googleapis.googlechat";
    private static final String FUNC_ON_MESSAGE = "onMessage";
    private static final String FUNC_ON_ADDED_TO_SPACE = "onAddedToSpace";
    private static final String FUNC_ON_REMOVED_FROM_SPACE = "onRemovedFromSpace";
    private static final String FUNC_ON_CARD_CLICKED = "onCardClicked";
    private static final String FUNC_ON_APP_HOME = "onAppHome";
    private static final String FUNC_ON_SUBMIT_FORM = "onSubmitForm";
    private static final Set<String> VALID_REMOTE_METHODS = new HashSet<>(Set.of(
            FUNC_ON_MESSAGE,
            FUNC_ON_ADDED_TO_SPACE,
            FUNC_ON_REMOVED_FROM_SPACE,
            FUNC_ON_CARD_CLICKED,
            FUNC_ON_APP_HOME,
            FUNC_ON_SUBMIT_FORM
    ));

    private ChatEventDispatcher() {
    }

    /**
     * Invokes a remote function on the given service object, injecting {@code ChatEvent} and optionally {@code Caller}
     * based on the function signature.
     * <p>
     * Called from Ballerina via {@code @java:Method} external binding.
     *
     * @param env           the Ballerina runtime environment
     * @param chatEvent     the ChatEvent record (BMap)
     * @param chatClient    the internal googlechat:Client BObject for API calls
     * @param spaceId       the space ID extracted from the event
     * @param eventFunction the name of the remote function to invoke
     * @param serviceObj    the user's ChatService object
     * @return {@code null} after scheduling the invocation
     */
    public static Object invokeRemoteFunction(Environment env, BMap<BString, Object> chatEvent, BObject chatClient,
                                              BString spaceId, BString eventFunction, BObject serviceObj) {
        Runtime runtime = env.getRuntime();
        String functionName = eventFunction.getValue();

        MethodType remoteFunction = getAttachedFunction(serviceObj, functionName);
        if (remoteFunction == null) {
            return null;
        }

        Parameter[] parameters = remoteFunction.getParameters();
        Object[] args = new Object[parameters.length];
        boolean callerFound = false;

        for (int i = 0; i < parameters.length; i++) {
            Type referredType = TypeUtils.getReferredType(parameters[i].type);
            if (referredType.getTag() == TypeTags.OBJECT_TYPE_TAG) {
                if (callerFound) {
                    logInvalidSignature(functionName, "multiple Caller parameters are not supported");
                    return null;
                }
                callerFound = true;
                args[i] = createCallerObject(chatClient, spaceId);
            } else if (referredType.getTag() == TypeTags.RECORD_TYPE_TAG &&
                    CHAT_EVENT_RECORD.equals(referredType.getName())) {
                args[i] = chatEvent;
            } else {
                logInvalidSignature(functionName, "unsupported parameter type '" + referredType.getName() + "'");
                return null;
            }
        }

        ObjectType serviceType = (ObjectType) TypeUtils.getReferredType(TypeUtils.getType(serviceObj));
        boolean isConcurrentSafe = serviceType.isIsolated() && serviceType.isIsolated(functionName);
        Map<String, Object> properties = getProperties(functionName);
        StrandMetadata strandMetadata = new StrandMetadata(isConcurrentSafe, properties);

        Thread.startVirtualThread(() -> {
            try {
                Object result = runtime.callMethod(serviceObj, functionName, strandMetadata, args);
                if (result instanceof BError bError) {
                    logError(functionName, bError);
                }
            } catch (BError bError) {
                logError(functionName, bError);
            } catch (Throwable throwable) {
                ERR_OUT.println("Unexpected error occurred while dispatching Google Chat event to "
                        + functionName + ": " + throwable.getMessage());
                throwable.printStackTrace(ERR_OUT);
            }
        });
        return null;
    }

    /**
     * Creates a {@code Caller} BObject by invoking its Ballerina init function with the chat client, space ID, and
     * message ID.
     */
    private static BObject createCallerObject(BObject chatClient, BString spaceId) {
        return ValueCreator.createObjectValue(ModuleUtils.getModule(),
                CALLER_OBJECT, chatClient, spaceId);
    }

    public static boolean requiresCaller(BObject serviceObj, BString eventFunction) {
        MethodType remoteFunction = getAttachedFunction(serviceObj, eventFunction.getValue());
        if (remoteFunction == null) {
            return false;
        }
        for (Parameter parameter : remoteFunction.getParameters()) {
            Type referredType = TypeUtils.getReferredType(parameter.type);
            if (referredType.getTag() == TypeTags.OBJECT_TYPE_TAG && CALLER_OBJECT.equals(referredType.getName())) {
                return true;
            }
        }
        return false;
    }

    public static Object validateService(BObject serviceObj) {
        ServiceType serviceType = (ServiceType) TypeUtils.getReferredType(TypeUtils.getType(serviceObj));
        RemoteMethodType[] remoteMethods = serviceType.getRemoteMethods();
        for (RemoteMethodType remoteMethod : remoteMethods) {
            String methodName = remoteMethod.getName();
            if (!VALID_REMOTE_METHODS.contains(methodName)) {
                return createValidationError("Unsupported remote method '" + methodName +
                        "' in ChatService. Allowed methods are: onMessage, onAddedToSpace, onRemovedFromSpace, " +
                        "onCardClicked, onAppHome, onSubmitForm");
            }
            BError validationError = validateRemoteMethod(remoteMethod);
            if (validationError != null) {
                return validationError;
            }
        }
        return null;
    }

    private static BError validateRemoteMethod(RemoteMethodType remoteMethod) {
        Parameter[] parameters = remoteMethod.getParameters();
        String methodName = remoteMethod.getName();
        if (parameters.length < 1 || parameters.length > 2) {
            return createValidationError("Invalid parameter count for remote method '" + methodName +
                    "'. Expected (ChatEvent) or (ChatEvent, Caller)");
        }

        Type firstType = TypeUtils.getReferredType(parameters[0].type);
        if (firstType.getTag() != TypeTags.RECORD_TYPE_TAG || !CHAT_EVENT_RECORD.equals(firstType.getName())) {
            return createValidationError("Invalid first parameter for remote method '" + methodName +
                    "'. Expected ChatEvent");
        }

        if (parameters.length == 2) {
            Type secondType = TypeUtils.getReferredType(parameters[1].type);
            if (secondType.getTag() != TypeTags.OBJECT_TYPE_TAG ||
                    !CALLER_OBJECT.equals(secondType.getName())) {
                return createValidationError("Invalid second parameter for remote method '" + methodName +
                        "'. Expected Caller");
            }
        }

        Type returnType = remoteMethod.getReturnType();
        if (returnType != null && !isValidReturnType(returnType)) {
            return createValidationError("Invalid return type for remote method '" + methodName +
                    "'. Expected error? or ()");
        }
        return null;
    }

    private static boolean isValidReturnType(Type returnType) {
        Type referredReturnType = TypeUtils.getReferredType(returnType);
        if (referredReturnType.getTag() == TypeTags.NULL_TAG || referredReturnType.getTag() == TypeTags.ERROR_TAG) {
            return true;
        }
        if (referredReturnType.getTag() != TypeTags.UNION_TAG) {
            return false;
        }
        UnionType unionType = (UnionType) referredReturnType;
        boolean hasError = false;
        boolean hasNil = false;
        for (Type memberType : unionType.getMemberTypes()) {
            Type referredMemberType = TypeUtils.getReferredType(memberType);
            if (referredMemberType.getTag() == TypeTags.ERROR_TAG) {
                hasError = true;
            } else if (referredMemberType.getTag() == TypeTags.NULL_TAG) {
                hasNil = true;
            } else {
                return false;
            }
        }
        return hasError && hasNil;
    }

    private static BError createValidationError(String message) {
        return ErrorCreator.createDistinctError("ListenerError", ModuleUtils.getModule(),
                StringUtils.fromString(message));
    }

    /**
     * Finds a remote function by name on the given service object.
     */
    private static MethodType getAttachedFunction(BObject serviceObj, String functionName) {
        ObjectType serviceType = (ObjectType) TypeUtils.getReferredType(TypeUtils.getType(serviceObj));
        MethodType[] methods = serviceType.getMethods();
        for (MethodType method : methods) {
            if (functionName.equals(method.getName())) {
                return method;
            }
        }
        return null;
    }

    /**
     * Builds properties map for strand metadata.
     */
    private static Map<String, Object> getProperties(String resourceName) {
        Map<String, Object> properties = new HashMap<>();
        properties.put("moduleOrg", ORG_NAME);
        properties.put("moduleName", MODULE_NAME);
        properties.put("moduleVersion", ModuleUtils.getModule().getMajorVersion());
        properties.put("parentFunctionName", resourceName);
        return properties;
    }

    private static void logError(String functionName, BError bError) {
        ERR_OUT.println("Error occurred while dispatching Google Chat event to "
                + functionName + ": " + bError.getMessage());
        bError.printStackTrace(ERR_OUT);
    }

    private static void logInvalidSignature(String functionName, String detail) {
        ERR_OUT.println("Skipping dispatch for Google Chat remote method '" + functionName + "': " + detail);
    }
}
