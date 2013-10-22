# dart-google-oauth2-library

[![Build Status](https://drone.io/github.com/dart-gde/dart-google-oauth2-library/status.png)](https://drone.io/github.com/dart-gde/dart-google-oauth2-library/latest)

### Description

Dart library to use for Google OAuth2 authentication / Client-side flow


### Usage/Installation


Go to [Google APIs Console](https://code.google.com/apis/console/) and create a new Project
Create a new `Client ID` for web applications in "API Access"
Set JavaScript origins to your server or for example `http://127.0.0.1:3030/` for local testing in Dartium

Add this dependency to your pubspec.yaml

```
  dependencies:
    google_oauth2_client: '>=0.2.18'
```

### Web applications

Import the library in your dart application

```
  import "package:google_oauth2_client/google_oauth2_browser.dart";
```

Initialize the library with your parameters

```
final auth = new GoogleOAuth2(
  "YOUR CLIENT ID HERE",
  ["scope1", "scope2", ...],
  tokenLoaded:oauthReady,
  autoLogin: <true/false>);
```

The `oauthReady` function will be called once your app has a valid OAuth token to call the APIs.
If you set `autoLogin` to `true` and the user has authorized the app in the past, this will happen automatically.
Otherwise, you need to call `auth.login()` to trigger a confirmation dialog.

Once you have an access token you can use the following to send authenticated requests to the API.

```
var request = new HttpRequest();
request.onLoad.listen(...)
request.open(method, url);
request.setRequestHeader("Authorization", "${auth.token.type} ${auth.token.data}");
request.send();
```

Or you can use the `authenticate` method of the OAuth2 class that takes a request, refreshes the access token if necessary and returns a request with the headers set correctly.

```
var request = new HttpRequest();
request.onLoad.listen(...);
request.open(method, url);
auth.authenticate(request).then((request) => request.send());
```

If you have an access token already (f.e. by using the Chrome Extension Identity API) you can use the SimpleOAuth2 class instead, that also supports the `authenticate` method.

```
var auth = new SimpleOAuth2(myToken);
var request new HttpRequest();
request.onLoad.listen(...);
request.open(method, url);
auth.authenticate(request).then((request) => request.send());
```


See [example/oauth_example.dart](https://github.com/dart-gde/dart-google-oauth2-library/blob/master/example/oauth_example.dart) for example login and request.

### Console applications

Import the library in your dart application

```
  import "package:google_oauth2_client/google_oauth2_console.dart";
```
Setup the `identifier` and `secret` by creating a [Google Installed App](https://developers.google.com/accounts/docs/OAuth2InstalledApp) client id in [APIs Console](https://code.google.com/apis/console)

```
  String identifier = "YOUR IDENTIFIER HERE";
  String secret = "YOUR SECRET HERE";
  List scopes =   ["scope1", "scope2", ...];
  final auth = new OAuth2Console(identifier: identifier, secret: secret, scopes: scopes);
```

When making calls the `OAuth2Console` provides a `widthClient` method that will provide you with the `http.Client` which to make requests. This may change in the future, for now it handles if the client has not allowed access to this application. credentials are stored locally by default in a file named `credentials.json`. Also by default the application does not check googles certificates, a certificate is provided [ca-certificates.crt](lib/src/console/oauth2_console_client/ca-certificates.crt). Place the certificate in the same folder as the application curl will check cert before executing.

```
  Future clientCallback(http.Client client) {
    var completer = new Completer();
    final url = "https://www.googleapis.com/plus/v1/people/me";
    client.get(url).then((http.Response response) {
      var data = JSON.parse(response.body);
      print("Logged in as ${data["displayName"]}");
    });
    return completer.future;
  };

  auth.withClient(clientCallback);
```

Example below, the user needs to open the link provided to allow for offline support of the application.

```
~/dart/dart-google-oauth2-library/example$ dart oauth_example_console.dart

Client needs your authorization for scopes [https://www.googleapis.com/auth/plus.me]
In a web browser, go to https://accounts.google.com/o/oauth2/auth?access_type=offline&approval_prompt=force&response_type=code&client_id=299615367852-n0kfup30mfj5emlclfgud9g76itapvk9.apps.googleusercontent.com&redirect_uri=http%3A%2F%2Flocalhost%3A60476&scope=https%3A%2F%2Fwww.googleapis.com%2Fauth%2Fplus.me
Then click "Allow access".

Waiting for your authorization...
Authorization received, processing...
Successfully authorized.

Logged in as Adam Singer
```

Currently console oauth2 does not work on windows yet. Mac and Linux should work if `curl` is in your path. `curl` is being used for passing the auth token from the browser back to the application.

### Disclaimer

No guarantees about the security or functionality of this libary

### Licenses

```
Copyright (c) 2013 Gerwin Sturm & Adam Singer

Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License. You may obtain a copy of
the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations under
the License

------------------------
Based on http://code.google.com/p/google-api-dart-client

Copyright 2012 Google Inc.
Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License. You may obtain a copy of
the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations under
the License
```
