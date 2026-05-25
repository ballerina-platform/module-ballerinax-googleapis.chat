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
import ballerina/url;

@test:Config {}
function testQueryParamEmpty() returns error? {
    test:assertEquals(check getPathForQueryParam({}), "");
}

@test:Config {}
function testQueryParamSingleString() returns error? {
    test:assertEquals(check getPathForQueryParam({"pageToken": "abc123"}), "?pageToken=abc123");
}

@test:Config {}
function testQueryParamMultiplePreservesOrder() returns error? {
    string result = check getPathForQueryParam({"pageSize": 5, "pageToken": "tok"});
    test:assertEquals(result, "?pageSize=5&pageToken=tok");
}

@test:Config {}
function testQueryParamStringifiesInt() returns error? {
    test:assertEquals(check getPathForQueryParam({"pageSize": 25}), "?pageSize=25");
}

@test:Config {}
function testQueryParamStringifiesBoolean() returns error? {
    test:assertEquals(check getPathForQueryParam({"useAdminAccess": true}), "?useAdminAccess=true");
}

@test:Config {}
function testQueryParamSkipsNilValues() returns error? {
    map<anydata> params = {"pageSize": (), "filter": "active", "pageToken": ()};
    test:assertEquals(check getPathForQueryParam(params), "?filter=active");
}

@test:Config {}
function testQueryParamEncodesSpecialChars() returns error? {
    string filterValue = string `spaceType = "SPACE"`;
    string result = check getPathForQueryParam({"filter": filterValue});

    test:assertTrue(result.startsWith("?filter="), "should start with ?filter=");
    test:assertFalse(result.includes(" "), "encoded path must not contain raw spaces");
    test:assertFalse(result.includes("\""), "encoded path must not contain raw quotes");

    string encodedValue = result.substring("?filter=".length());
    test:assertEquals(check url:decode(encodedValue, "UTF-8"), filterValue);
}

@test:Config {}
function testQueryParamEncodesAmpersandInValue() returns error? {
    string result = check getPathForQueryParam({"filter": "a&b"});
    test:assertFalse(result.includes("a&b"), "raw '&' in value must be encoded");
    string encodedValue = result.substring("?filter=".length());
    test:assertEquals(check url:decode(encodedValue, "UTF-8"), "a&b");
}

@test:Config {}
function testQueryParamFromQueriesRecord() returns error? {
    ListSpacesQueries queries = {pageSize: 10, filter: "spaceType = \"SPACE\""};
    string result = check getPathForQueryParam(queries);

    test:assertTrue(result.startsWith("?"), "should begin with ?");
    test:assertTrue(result.includes("pageSize=10"), "should include pageSize");
    test:assertTrue(result.includes("filter="), "should include filter");
    test:assertFalse(result.includes("pageToken"), "absent optional must be dropped");
    test:assertFalse(result.includes(" "), "encoded path must not contain raw spaces");
}
