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
import ballerina/jwt;
import ballerina/log;

// ═══════════════════════════════════════════════════════════════════════════════
// HTTP Mode Bearer Token Verification
// ═══════════════════════════════════════════════════════════════════════════════
//
// Google Chat sends a bearer token in the `Authorization` header of every HTTP
// request to your endpoint so you can verify the request comes from Chat.
//
// Two verification approaches are supported, each represented by its own config
// type:
//
// 1. HttpEndpointUrlConfig (recommended):
//    The bearer token is a Google-signed OIDC ID token. The `email` claim is
//    `chat@system.gserviceaccount.com` and the `audience` claim matches the
//    HTTP endpoint URL configured in Google Cloud Console.
//    Verified using Google's OIDC public keys (JWKS).
//
// 2. ProjectNumberConfig:
//    The bearer token is a self-signed JWT issued and signed by
//    `chat@system.gserviceaccount.com`. The `audience` claim is the GCP
//    project number used to build the Chat app.
//    Verified using the service account's public X.509 certificates.
//
// In both cases, if verification fails the request is rejected with HTTP 401.
// ═══════════════════════════════════════════════════════════════════════════════

# Extracts the bearer token from the `Authorization` header of an HTTP request.
#
# Expects the header value to be in the form `Bearer <token>`.
#
# + request - The incoming HTTP request
# + return - The raw bearer token string, or an `AuthenticationError` if the
# header is absent or malformed
isolated function extractBearerToken(http:Request request) returns string|AuthenticationError {
    string|http:HeaderNotFoundError authHeader = request.getHeader("Authorization");
    if authHeader is http:HeaderNotFoundError {
        return error AuthenticationError(ERR_BEARER_TOKEN_MISSING);
    }
    if !authHeader.startsWith("Bearer ") {
        return error AuthenticationError(ERR_BEARER_TOKEN_MISSING);
    }
    string token = authHeader.substring(7);
    if token == "" {
        return error AuthenticationError(ERR_BEARER_TOKEN_MISSING);
    }
    return token;
}

# Verifies a bearer token from an incoming Google Chat HTTP request.
#
# Dispatches to the appropriate verification strategy based on the runtime
# type of `config`:
# - `HttpEndpointUrlConfig` → OIDC ID token verified against the endpoint URL
# - `ProjectNumberConfig`   → self-signed JWT verified against the project number
#
# + bearerToken - The raw bearer token extracted from the `Authorization` header
# + config - The HTTP configuration — either `HttpEndpointUrlConfig` or
# `ProjectNumberConfig`
# + return - `true` if verification succeeds, an `AuthenticationError` otherwise
isolated function verifyChatBearerToken(string bearerToken,
        HttpConfig config) returns true|AuthenticationError {
    if config is HttpEndpointUrlConfig {
        return verifyIdToken(bearerToken, config.endpointUrl);
    }
    return verifyProjectNumberJwt(bearerToken, config.projectNumber);
}

# Verifies a Google-signed OIDC ID token (`HttpEndpointUrlConfig` approach).
#
# The token must:
# - Be signed by Google (validated via JWKS at `accounts.google.com`)
# - Have `issuer` equal to `accounts.google.com` or `https://accounts.google.com`
# - Have `email` == `chat@system.gserviceaccount.com`
# - Have `email_verified` == `true`
# - Have `audience` matching the configured HTTP endpoint URL
#
# + token - The raw JWT string from the Authorization header
# + expectedAudience - The HTTP endpoint URL configured in Google Cloud Console
# + return - `true` on success, or an `AuthenticationError` if validation fails
isolated function verifyIdToken(string token,
        string expectedAudience) returns true|AuthenticationError {
    jwt:Payload|jwt:Error validationResult = validateGoogleIdToken(token, expectedAudience, GOOGLE_OIDC_ISSUER_URL);
    if validationResult is jwt:Error {
        validationResult = validateGoogleIdToken(token, expectedAudience, GOOGLE_OIDC_ISSUER);
    }
    if validationResult is jwt:Error {
        log:printDebug("ID token validation failed", 'error = validationResult,
                expectedAudience = expectedAudience);
        return error AuthenticationError(ERR_BEARER_TOKEN_INVALID, validationResult);
    }

    jwt:Payload payload = validationResult;
    anydata? emailClaim = payload["email"];
    if emailClaim !is string || emailClaim != CHAT_ISSUER {
        return error AuthenticationError(ERR_BEARER_TOKEN_INVALID,
            error("ID token contained invalid email claim"));
    }

    anydata? emailVerifiedClaim = payload["email_verified"];
    if emailVerifiedClaim !is boolean || !emailVerifiedClaim {
        return error AuthenticationError(ERR_BEARER_TOKEN_INVALID,
            error("ID token email claim is not verified"));
    }

    return true;
}

isolated function validateGoogleIdToken(string token, string expectedAudience,
        string expectedIssuer) returns jwt:Payload|jwt:Error {
    jwt:ValidatorConfig validatorConfig = {
        issuer: expectedIssuer,
        audience: expectedAudience,
        signatureConfig: {
            jwksConfig: {
                url: GOOGLE_OIDC_CERTS_URL
            }
        }
    };
    return jwt:validate(token, validatorConfig);
}

# Verifies a self-signed JWT bearer token (`ProjectNumberConfig` approach).
#
# The token must:
# - Be signed by `chat@system.gserviceaccount.com` (validated via the Chat
# service account's published JWKS)
# - Have `issuer` == `chat@system.gserviceaccount.com`
# - Have `audience` matching the configured GCP project number
#
# + token - The raw JWT string from the Authorization header
# + expectedAudience - The GCP project number configured in Google Cloud Console
# + return - `true` on success, or an `AuthenticationError` if validation fails
isolated function verifyProjectNumberJwt(string token,
        string expectedAudience) returns true|AuthenticationError {
    jwt:ValidatorConfig validatorConfig = {
        issuer: CHAT_ISSUER,
        audience: expectedAudience,
        signatureConfig: {
            jwksConfig: {
                url: GOOGLE_SA_JWKS_URL
            }
        }
    };

    jwt:Payload|jwt:Error result = jwt:validate(token, validatorConfig);
    if result is jwt:Error {
        log:printDebug("Project Number JWT validation failed", 'error = result,
                expectedAudience = expectedAudience);
        return error AuthenticationError(ERR_BEARER_TOKEN_INVALID, result);
    }
    return true;
}
