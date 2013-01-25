# dart-google-oauth2-library

### Description

Dart library to use for Google OAuth2 authentication / Client-side flow


### Usage/Installation


Go to [Google APIs Console](https://code.google.com/apis/console/) and create a new Project
Create a new `Client ID` for web applications in "API Access"
Set JavaScript origins to your server or for example `http://127.0.0.1:3030/` for local testing in Dartium

Add this dependency to your pubspec.yaml

```
  dependencies:
    google_oauth2_client: '>=0.2.0'
```

### Web applications

Import the library in your dart application

```
  import "package:google_oauth2_client/google_oauth2_browser.dart";
```

Initialize the library with your parameters

```
final auth = new OAuth2(
  "YOUR CLIENT ID HERE",
  ["scope1", "scope2", ...],
  tokenLoaded:oauthReady);
```

The `oauthReady` function will be called once your app has a valid OAuth token to call the APIs.
If the user has authorized the app in the past, this will happen automatically.
Otherwise, you need to call `auth.login()` to trigger a confirmation dialog.

Once you have an access token you can use the following to send authenticated requests to the API.

```
  request.setRequestHeader("Authorization", "${auth.token.type} ${auth.token.data}");
```

See [example/oauth_example.dart](https://github.com/dart-gde/dart-google-oauth2-library/blob/master/example/oauth_example.dart) for example login and request.

### Console applications

Import the library in your dart application

```
  import "package:google_oauth2_client/google_oauth2_console.dart";
```

...

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
