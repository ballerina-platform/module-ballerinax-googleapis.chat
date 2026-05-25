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
import ballerina/http;
import ballerina/jwt;
import ballerina/time;
import ballerina/url;

# JSON shape of a successful Google OAuth2 token response.
#
# + access_token - The OAuth2 access token to attach to outgoing API requests
# + expires_in - Token lifetime in seconds from issuance
# + token_type - The token type (typically `Bearer`); not used by this connector
type TokenResponse record {
    string access_token;
    int expires_in;
    string token_type?;
};

# Self-managed service-account access token provider.
#
# Holds the PEM private key as a plain string (no native data) and decodes it
# inside the refresh path as a local variable, so the `crypto:PrivateKey` never
# crosses an isolated-class clone boundary. The cached access token is a string
# plus an epoch-seconds expiry, both safe to read under a `lock`.
isolated class ServiceAccountTokenProvider {
    private final string issuer;
    private final string pemPrivateKey;
    private final string scope;
    private final http:Client tokenClient;

    private string? cachedAccessToken = ();
    private int cachedExpiryEpochSec = 0;

    isolated function init(string issuer, string pemPrivateKey, string scope) returns error? {
        self.issuer = issuer;
        self.pemPrivateKey = pemPrivateKey;
        self.scope = scope;
        self.tokenClient = check new (GOOGLE_OAUTH2_TOKEN_URL);
    }

    # Returns a valid access token, refreshing if the cache is empty or within
    # `TOKEN_REFRESH_SKEW_SECONDS` of expiry.
    #
    # + return - A valid OAuth2 access token, or an error if refresh fails
    isolated function getAccessToken() returns string|error {
        lock {
            int nowSec = <int>time:utcNow()[0];
            string? cached = self.cachedAccessToken;
            if cached is string && nowSec + TOKEN_REFRESH_SKEW_SECONDS < self.cachedExpiryEpochSec {
                return cached;
            }
            [string, int] [token, expiryEpochSec] = check self.refresh();
            self.cachedAccessToken = token;
            self.cachedExpiryEpochSec = expiryEpochSec;
            return token;
        }
    }

    # Mints a fresh JWT assertion, exchanges it for an access token, and returns
    # `[accessToken, expiryEpochSec]`.
    #
    # + return - Tuple of `[accessToken, expiryEpochSec]`, or an error if the
    # JWT could not be signed or the token endpoint rejected the assertion
    private isolated function refresh() returns [string, int]|error {
        crypto:PrivateKey privateKey = check crypto:decodeRsaPrivateKeyFromContent(self.pemPrivateKey.toBytes());
        jwt:IssuerConfig issuerConfig = {
            issuer: self.issuer,
            username: self.issuer,
            audience: GOOGLE_OAUTH2_TOKEN_URL,
            expTime: <decimal>TOKEN_LIFETIME_SECONDS,
            signatureConfig: {config: privateKey},
            customClaims: {"scope": self.scope}
        };
        string assertion = check jwt:issue(issuerConfig);
        string encodedAssertion = check url:encode(assertion, "UTF-8");
        string formBody = "grant_type=" + check url:encode(JWT_BEARER_GRANT_TYPE, "UTF-8")
            + "&assertion=" + encodedAssertion;

        http:Request request = new;
        request.setTextPayload(formBody, "application/x-www-form-urlencoded");
        TokenResponse response = check self.tokenClient->post("", request, targetType = TokenResponse);
        int expiryEpochSec = <int>time:utcNow()[0] + response.expires_in;
        return [response.access_token, expiryEpochSec];
    }
}
