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

# Represents an error originating from the Google Chat trigger listener.
public type ListenerError distinct error;

# Represents an error originating from the Google Chat API client.
public type ClientError distinct error;

# Represents an error when resolving service account credentials.
public type ServiceAccountError distinct error;

# Represents an error when Pub/Sub topic or subscription management fails.
public type PubSubError distinct error;

# Represents an error when dispatching an event to the service fails.
public type DispatchError distinct error;

# Represents an error when payload parsing or validation fails.
public type PayloadValidationError distinct error;

# Represents an error when a request from Google Chat fails bearer token verification.
# Returned when an incoming HTTP request does not carry a valid Google-signed token.
public type AuthenticationError distinct error;
