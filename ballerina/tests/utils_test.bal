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

import ballerina/test;

const string VALID_SA_PATH = "tests/resources/service_account/valid_sa.json";
const string INVALID_SA_PATH = "tests/resources/service_account/invalid_type_sa.json";

@test:Config {}
function testNormalizeServiceAccountFromCredentials() returns error? {
    ServiceAccountCredentials credentials = {
        'type: "service_account",
        client_email: "bot@project.iam.gserviceaccount.com",
        private_key: "-----BEGIN PRIVATE KEY-----\nABC\n-----END PRIVATE KEY-----\n"
    };
    ServiceAccountKeyMaterial material = check normalizeServiceAccountAuth(credentials);
    test:assertEquals(material.issuer, "bot@project.iam.gserviceaccount.com");
    test:assertTrue(material.pemPrivateKey.startsWith("-----BEGIN PRIVATE KEY-----"));
}

@test:Config {}
function testNormalizeServiceAccountFromFile() returns error? {
    ServiceAccountFileConfig fileConfig = {path: VALID_SA_PATH};
    ServiceAccountKeyMaterial material = check normalizeServiceAccountAuth(fileConfig);
    test:assertEquals(material.issuer, "mock-bot@mock-project.example.com");
}

@test:Config {}
function testNormalizeServiceAccountWrongType() {
    ServiceAccountCredentials credentials = {
        'type: "authorized_user",
        client_email: "bot@project.iam.gserviceaccount.com",
        private_key: "key"
    };
    ServiceAccountKeyMaterial|error material = normalizeServiceAccountAuth(credentials);
    test:assertTrue(material is ServiceAccountError);
}

@test:Config {}
function testLoadServiceAccountCredentials() returns error? {
    ServiceAccountCredentials credentials = check loadServiceAccountCredentials(VALID_SA_PATH);
    test:assertEquals(credentials.'type, "service_account");
    test:assertEquals(credentials.client_email, "mock-bot@mock-project.example.com");
}

@test:Config {}
function testLoadServiceAccountCredentialsWrongType() {
    ServiceAccountCredentials|error credentials = loadServiceAccountCredentials(INVALID_SA_PATH);
    test:assertTrue(credentials is ServiceAccountError);
}

@test:Config {}
function testLoadServiceAccountCredentialsMissingFile() {
    ServiceAccountCredentials|error credentials = loadServiceAccountCredentials("tests/resources/does_not_exist.json");
    test:assertTrue(credentials is error);
}

// The token provider mints a JWT from the PEM key before exchanging it. A malformed
// PEM fails at the decode step, so getAccessToken() returns an error without any
// network call to Google.
@test:Config {}
function testTokenProviderMalformedKey() returns error? {
    ServiceAccountTokenProvider provider = check new ("bot@project.iam.gserviceaccount.com",
        "not-a-valid-pem-key", CHAT_BOT_SCOPE
    );
    string|error token = provider.getAccessToken();
    test:assertTrue(token is error);
}
