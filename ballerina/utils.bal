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

import ballerina/crypto;
import ballerina/io;
import ballerina/log;

type GoogleServiceAccountFile record {|
    string 'type;
    string client_email;
    string private_key;
    string project_id?;
    string private_key_id?;
    string client_id?;
    string auth_uri?;
    string token_uri?;
    string auth_provider_x509_cert_url?;
    string client_x509_cert_url?;
    string universe_domain?;
|};

isolated function normalizeServiceAccountAuth(ServiceAccountAuthConfig config) returns ServiceAccountConfig|error {
    if config is ServiceAccountConfig {
        return config;
    }

    ServiceAccountCredentials credentials = config is ServiceAccountCredentials
        ? config
        : check loadServiceAccountCredentials((<ServiceAccountFileConfig>config).path);
    return normalizeServiceAccountCredentials(credentials);
}

isolated function loadServiceAccountCredentials(string path) returns ServiceAccountCredentials|error {
    io:ReadableByteChannel byteChannel = check io:openReadableFile(path);
    io:ReadableCharacterChannel charChannel = new (byteChannel, "UTF-8");
    json|error content = charChannel.readJson();
    error? closeError = charChannel.close();
    if closeError is error {
        log:printWarn("Failed to close service account credentials file", 'error = closeError, path = path);
    }
    json credentialsJson = check content;
    GoogleServiceAccountFile rawCredentials = check credentialsJson.cloneWithType(GoogleServiceAccountFile);
    if rawCredentials.'type != "service_account" {
        return error ServiceAccountError("Invalid service account credentials type: expected 'service_account'");
    }
    return check credentialsJson.cloneWithType(ServiceAccountCredentials);
}

isolated function normalizeServiceAccountCredentials(ServiceAccountCredentials credentials) returns ServiceAccountConfig|error {
    if credentials.'type != "service_account" {
        return error ServiceAccountError("Invalid service account credentials type: expected 'service_account'");
    }

    crypto:PrivateKey privateKey = check crypto:decodeRsaPrivateKeyFromContent(credentials.private_key.toBytes());
    return {
        issuer: credentials.client_email,
        signatureConfig: {
            config: privateKey
        }
    };
}
