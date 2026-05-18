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
 * and injects the {@code ChatEvent} record and a pre-built event-specific Caller into the arguments.
 * <p>
 * The handler is executed on a virtual thread (fire-and-forget). The Caller holds an {@code http:Caller} reference so
 * the user's handler can write the HTTP response immediately via {@code respond()}.
 *
 * @since 0.2.0
 */
public final class ChatEventDispatcher {

    private static final PrintStream ERR_OUT = System.err;
    private static final String ORG_NAME = "ballerinax";
    private static final String MODULE_NAME = "googleapis.chat";

    // Remote function names
    private static final String FUNC_ON_MESSAGE = "onMessage";
    private static final String FUNC_ON_ADDED_TO_SPACE = "onAddedToSpace";
    private static final String FUNC_ON_REMOVED_FROM_SPACE = "onRemovedFromSpace";
    private static final String FUNC_ON_CARD_CLICKED = "onCardClicked";
    private static final String FUNC_ON_WIDGET_UPDATED = "onWidgetUpdated";
    private static final String FUNC_ON_APP_COMMAND = "onAppCommand";
    private static final String FUNC_ON_APP_HOME = "onAppHome";
    private static final String FUNC_ON_SUBMIT_FORM = "onSubmitForm";

    private static final Set<String> VALID_REMOTE_METHODS = new HashSet<>(Set.of(
            FUNC_ON_MESSAGE, FUNC_ON_ADDED_TO_SPACE, FUNC_ON_REMOVED_FROM_SPACE,
            FUNC_ON_CARD_CLICKED, FUNC_ON_WIDGET_UPDATED, FUNC_ON_APP_COMMAND,
            FUNC_ON_APP_HOME, FUNC_ON_SUBMIT_FORM
    ));

    // Record types resolve cleanly via an empty record value. Caller object types do not — their inits
    // take parameters (chatClient, spaceId, responseFuture), so ValueCreator.createObjectValue would
    // crash at class load. We identify Callers by module + type name
    private static final Type CHAT_EVENT_TYPE =
            ValueCreator.createRecordValue(ModuleUtils.getModule(), "ChatEvent").getType();
    private static final Type MESSAGE_EVENT_TYPE =
            ValueCreator.createRecordValue(ModuleUtils.getModule(), "MessageEvent").getType();

    private static final String CALLER_MESSAGE = "MessageCaller";
    private static final String CALLER_APP_HOME = "AppHomeCaller";
    private static final String CALLER_CARD_CLICKED = "CardClickedCaller";
    private static final String CALLER_SUBMIT_FORM = "SubmitFormCaller";
    private static final String CALLER_WIDGET_UPDATED = "WidgetUpdatedCaller";

    private static final Set<String> CALLER_TYPE_NAMES = Set.of(
            CALLER_MESSAGE, CALLER_APP_HOME, CALLER_CARD_CLICKED, CALLER_SUBMIT_FORM, CALLER_WIDGET_UPDATED
    );

    // Map of function name to expected caller type name
    private static final Map<String, String> FUNCTION_CALLER_MAP = Map.of(
            FUNC_ON_MESSAGE, CALLER_MESSAGE,
            FUNC_ON_ADDED_TO_SPACE, CALLER_MESSAGE,
            FUNC_ON_APP_COMMAND, CALLER_MESSAGE,
            FUNC_ON_CARD_CLICKED, CALLER_CARD_CLICKED,
            FUNC_ON_APP_HOME, CALLER_APP_HOME,
            FUNC_ON_SUBMIT_FORM, CALLER_SUBMIT_FORM,
            FUNC_ON_WIDGET_UPDATED, CALLER_WIDGET_UPDATED
    );

    /**
     * Returns the simple name of the Caller object type if {@code type} is one of our event-specific Callers declared
     * in this module, otherwise {@code null}.
     */
    private static String matchedCallerName(Type type) {
        if (type.getTag() != TypeTags.OBJECT_TYPE_TAG) {
            return null;
        }
        if (!ModuleUtils.getModule().equals(type.getPackage())) {
            return null;
        }
        String name = type.getName();
        return CALLER_TYPE_NAMES.contains(name) ? name : null;
    }

    private ChatEventDispatcher() {
    }

    /**
     * Invokes a remote function on the given service object. The ChatEvent and the pre-built Caller are injected into
     * the arguments based on the function signature. The handler is executed on a virtual thread (fire-and-forget).
     *
     * @param env           the Ballerina runtime environment
     * @param chatEvent     the ChatEvent record (BMap)
     * @param eventFunction the name of the remote function to invoke
     * @param callerObj     the pre-built event-specific Caller BObject, or null for no-caller events
     * @param serviceObj    the user's ChatService object
     */
    public static void invokeRemoteFunction(Environment env, BMap<BString, Object> chatEvent,
                                            BString eventFunction, Object callerObj, BObject serviceObj) {
        Runtime runtime = env.getRuntime();
        String functionName = eventFunction.getValue();

        MethodType remoteFunction = getAttachedFunction(serviceObj, functionName);
        if (remoteFunction == null) {
            // Function not implemented — nothing to dispatch
            return;
        }

        Object[] args = buildArgs(remoteFunction.getParameters(), functionName, chatEvent, callerObj);
        if (args == null) {
            return;
        }

        // Fire-and-forget on a virtual thread
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
    }

    /**
     * Checks whether a remote function exists on the given service object. Called from Ballerina to determine whether
     * to create a Caller and dispatch, or to respond with an empty body immediately.
     *
     * @param serviceObj    the user's ChatService object
     * @param eventFunction the name of the remote function to check
     * @return {@code true} if the function exists, {@code false} otherwise
     */
    public static boolean hasRemoteFunction(BObject serviceObj, BString eventFunction) {
        return getAttachedFunction(serviceObj, eventFunction.getValue()) != null;
    }

    /**
     * Validates the service object to ensure all remote methods have valid signatures.
     */
    public static Object validateService(BObject serviceObj) {
        ServiceType serviceType = (ServiceType) TypeUtils.getReferredType(TypeUtils.getType(serviceObj));
        if (serviceType.getResourceMethods().length > 0) {
            return createValidationError("ChatService cannot have resource methods");
        }
        RemoteMethodType[] remoteMethods = serviceType.getRemoteMethods();
        for (RemoteMethodType remoteMethod : remoteMethods) {
            String methodName = remoteMethod.getName();
            if (!VALID_REMOTE_METHODS.contains(methodName)) {
                return createValidationError("Unsupported remote method '" + methodName +
                        "' in ChatService. Allowed methods are: onMessage, onAddedToSpace, onRemovedFromSpace, " +
                        "onCardClicked, onWidgetUpdated, onAppCommand, onAppHome, onSubmitForm");
            }
            BError validationError = validateRemoteMethod(remoteMethod, methodName);
            if (validationError != null) {
                return validationError;
            }
        }
        return null;
    }

    private static BError validateRemoteMethod(RemoteMethodType remoteMethod, String methodName) {
        Parameter[] parameters = remoteMethod.getParameters();

        if (parameters.length < 1 || parameters.length > 2) {
            return createValidationError("Invalid parameter count for remote method '" + methodName +
                    "'. Expected 1 or 2 parameters: (ChatEvent) or (ChatEvent, <Caller>)");
        }

        boolean isOnMessage = FUNC_ON_MESSAGE.equals(methodName);
        Type firstType = TypeUtils.getReferredType(parameters[0].type);
        boolean isValidFirstParam = TypeUtils.isSameType(CHAT_EVENT_TYPE, firstType) ||
                (isOnMessage && TypeUtils.isSameType(MESSAGE_EVENT_TYPE, firstType));
        if (!isValidFirstParam) {
            return createValidationError("Invalid first parameter for remote method '" + methodName +
                    "'. Expected parameter of type " + (isOnMessage ? "ChatEvent or MessageEvent" : "ChatEvent"));
        }

        if (parameters.length == 2) {
            Type secondType = TypeUtils.getReferredType(parameters[1].type);
            String expectedCaller = FUNCTION_CALLER_MAP.get(methodName);
            String actualCaller = matchedCallerName(secondType);
            if (expectedCaller == null || !expectedCaller.equals(actualCaller)) {
                return createValidationError("Invalid second parameter for remote method '" + methodName +
                        "'. Expected parameter of type " + expectedCaller);
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
        return ErrorCreator.createError(ModuleUtils.getModule(), "ListenerError",
                StringUtils.fromString(message), null, null);
    }

    /**
     * Builds the argument array for the remote function, injecting the ChatEvent and Caller into the appropriate slots
     * based on each parameter's declared type. Returns {@code null} if the signature is unsupported.
     */
    private static Object[] buildArgs(Parameter[] parameters, String functionName,
                                      BMap<BString, Object> chatEvent, Object callerObj) {
        Object[] args = new Object[parameters.length];
        for (int i = 0; i < parameters.length; i++) {
            Type referredType = TypeUtils.getReferredType(parameters[i].type);
            if (matchedCallerName(referredType) != null) {
                if (callerObj == null) {
                    logInvalidSignature(functionName, "caller parameter present but no caller available");
                    return null;
                }
                args[i] = callerObj;
            } else if (TypeUtils.isSameType(CHAT_EVENT_TYPE, referredType) ||
                    TypeUtils.isSameType(MESSAGE_EVENT_TYPE, referredType)) {
                args[i] = chatEvent;
            } else {
                logInvalidSignature(functionName, "unsupported parameter type '" + referredType.getName() + "'");
                return null;
            }
        }
        return args;
    }

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
