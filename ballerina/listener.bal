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
import ballerina/jballerina.java;
import ballerina/log;

# Google Chat trigger listener. Receives Google Chat interaction events via
# direct HTTP delivery from Google Chat.
#
# Google Chat sends interaction events directly to the listener's root path
# (`/`). Each request carries a bearer token in the `Authorization` header
# that is verified before processing.
#
# ## Usage
#
# ```ballerina
# listener chat:Listener chatListener = new (8090, {
#     auth: {
#         path: "/path/to/service-account.json"
#     }
# });
#
# @chat:ServiceConfig {
#     endpointUrl: "https://my-app.example.com"
# }
# service chat:ChatService on chatListener {
#     remote function onMessage(chat:MessageEvent event, chat:MessageCaller caller) returns error? {
#         check caller->respond({ text: "Hello!" });
#     }
# }
# ```
@display {label: "Google Chat", iconPath: "docs/icon.png"}
public class Listener {
    private http:Listener httpListener;
    private DispatcherService dispatcherService;
    private final Client chatClient;

    # Initializes the Google Chat trigger listener.
    #
    # + listenOn - The port or HTTP listener to listen on. Defaults to port 8000.
    # + config - Configuration including auth credentials
    # + return - An error if initialization fails
    public function init(int|http:Listener listenOn = 8000, *ListenerConfig config) returns error? {
        if listenOn is http:Listener {
            self.httpListener = listenOn;
        } else {
            self.httpListener = check new (listenOn, config.httpListenerConfig);
        }

        // Create the Chat API client — used by the Callers for async operations.
        self.chatClient = check new ({auth: config.auth});

        self.dispatcherService = new DispatcherService(self.chatClient);
    }

    # Attaches a `ChatService` implementation to this listener.
    #
    # Reads the `@ServiceConfig` annotation on the service to configure bearer
    # token verification settings.
    #
    # + serviceRef - The service to attach (must have a `@ServiceConfig` annotation)
    # + attachPoint - The attach point (unused, kept for API compatibility)
    # + return - An error if the annotation is missing
    public function attach(GenericServiceType serviceRef, () attachPoint) returns @tainted error? {
        typedesc<any> serviceTypedesc = typeof serviceRef;
        ServiceConfiguration? svcConfig = serviceTypedesc.@ServiceConfig;
        if svcConfig is () {
            return error ListenerError("@chat:ServiceConfig annotation is required on the service. " +
                "Provide an HttpEndpointUrlConfig (endpointUrl) or ProjectNumberConfig (projectNumber).");
        }
        check validateService(serviceRef);

        self.dispatcherService.setHttpConfig(svcConfig);
        log:printInfo("Google Chat listener started in HTTP mode");

        string serviceTypeStr = self.getServiceTypeStr(serviceRef);
        check self.dispatcherService.addServiceRef(serviceTypeStr, serviceRef);
    }

    # Detaches a `ChatService` implementation from this listener.
    #
    # + serviceRef - The service to detach
    # + return - An error if detachment fails
    public isolated function detach(GenericServiceType serviceRef) returns error? {
        string serviceTypeStr = self.getServiceTypeStr(serviceRef);
        check self.dispatcherService.removeServiceRef(serviceTypeStr);
    }

    # Starts the HTTP listener to begin receiving events.
    #
    # + return - An error if starting fails
    public isolated function 'start() returns error? {
        if !self.dispatcherService.hasServiceRefs() {
            return error ListenerError("No ChatService has been attached to this listener");
        }
        check self.httpListener.attach(self.dispatcherService, ());
        return self.httpListener.'start();
    }

    # Gracefully stops the listener.
    #
    # + return - An error if shutdown fails
    public isolated function gracefulStop() returns @tainted error? {
        return self.httpListener.gracefulStop();
    }

    # Immediately stops the listener.
    #
    # + return - An error if shutdown fails
    public isolated function immediateStop() returns error? {
        return self.httpListener.immediateStop();
    }

    # Returns the service type string for the given service reference.
    #
    # + serviceRef - The service reference
    # + return - The service type identifier string
    private isolated function getServiceTypeStr(GenericServiceType serviceRef) returns string {
        return "ChatService";
    }
}

isolated function validateService(GenericServiceType serviceObj) returns error? = @java:Method {
    name: "validateService",
    'class: "io.ballerina.lib.googleapis.chat.ChatEventDispatcher"
} external;
