// Copyright 2012 Google Inc.
// Originally part of http://code.google.com/p/google-api-dart-client
//
// Adapted as stand-alone OAuth library:
// Copyright 2013 Gerwin Sturm (scarygami.net/+)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library google_oauth2_browser;

import "dart:json" as JSON;
import "dart:html";
import "dart:typed_data";
import "dart:math";

import "dart:async";
import "src/common/url_pattern.dart";
export "src/common/url_pattern.dart";

part "src/browser/oauth2.dart";
part "src/browser/googleoauth2.dart";
part "src/browser/simpleoauth2.dart";
part "src/browser/proxy_callback.dart";
part "src/browser/token.dart";
part "src/browser/utils.dart";

void populateRequestAuthHeader(HttpRequest request, String tokenType,
                               String token) {
  request.setRequestHeader("Authorization", "${tokenType} ${token}");
}
