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
import ballerina/log;
import ballerina/uuid;

# Creates a Pub/Sub push subscription on a pre-existing topic.
#
# The topic must already exist and be configured in the Google Chat app
# connection settings in Google Cloud Console. This function derives the
# project ID from the topic resource name.
#
# + pubSubClient - Authenticated HTTP client for the Pub/Sub API
# + topicResource - Fully qualified topic resource name
#                   (e.g. `projects/my-project/topics/my-topic`)
# + callbackURL - Public URL where Pub/Sub will push events
# + return - Subscription resource name, or an error
isolated function createPushSubscription(http:Client pubSubClient, string topicResource,
        string callbackURL) returns SubscriptionDetail|error {
    // Derive project from topic resource name: "projects/<project>/topics/<name>"
    string[] parts = re `/`.split(topicResource);
    if parts.length() < 2 {
        return error PubSubError("Invalid topic resource name: " + topicResource);
    }
    string project = parts[1];

    string subscriptionName = SUBSCRIPTION_NAME_PREFIX + uuid:createType4AsString();
    string subscriptionResource = PROJECTS + project + SUBSCRIPTIONS + subscriptionName;

    Subscription subscription = check createSubscription(pubSubClient, subscriptionResource,
        topicResource, callbackURL);
    log:printInfo(LOG_PUBSUB_SUB_CREATED + subscription.name);

    return {subscriptionResource: subscriptionResource};
}

# Creates a Pub/Sub push subscription for the given topic.
#
# + pubSubClient - Authenticated Pub/Sub HTTP client
# + subscriptionResource - Fully qualified subscription resource name
# + topicResource - Fully qualified topic resource name
# + callbackURL - The webhook URL to push messages to
# + return - The created subscription or an error
isolated function createSubscription(http:Client pubSubClient, string subscriptionResource,
        string topicResource, string callbackURL) returns Subscription|error {
    SubscriptionRequest subscriptionRequest = {
        topic: topicResource,
        pushConfig: {
            pushEndpoint: callbackURL
        },
        ackDeadlineSeconds: 600
    };

    Subscription|error response = pubSubClient->put(subscriptionResource, subscriptionRequest,
        targetType = Subscription);
    if response is error {
        log:printError(ERR_SUBSCRIPTION_CREATION, response,
            subscriptionResource = subscriptionResource, topicResource = topicResource);
        return error PubSubError(ERR_SUBSCRIPTION_CREATION, response);
    }
    return response;
}

# Deletes a Pub/Sub subscription.
#
# + pubSubClient - Authenticated Pub/Sub HTTP client
# + subscriptionResource - Fully qualified subscription resource name
# + return - An error if deletion fails
isolated function deleteSubscription(http:Client pubSubClient, string subscriptionResource)
        returns error? {
    http:Response _ = check pubSubClient->delete(subscriptionResource);
}
