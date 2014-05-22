// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library oauth2;
import 'dart:core';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:oauth2/oauth2.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import "package:json_web_token/json_web_token.dart";

import 'http.dart';
import 'io.dart';
import 'log.dart' as log;
import 'utils.dart';

export 'package:oauth2/oauth2.dart';

class OAuth2Console {

  /// The pub client's OAuth2 identifier.
  String _identifier = "<IDENTIFIER>";

  /// The pub client's OAuth2 secret. This isn't actually meant to be kept a
  /// secret.
  String _secret = "<SECRET>";

  /// The URL to which the user will be directed to authorize the pub client to
  /// get an OAuth2 access token.
  ///
  /// `access_type=offline` and `approval_prompt=force` ensures that we always get
  /// a refresh token from the server. See the [Google OAuth2 documentation][].
  ///
  /// [Google OAuth2 documentation]: https://developers.google.com/accounts/docs/OAuth2WebServer#offline
  Uri _authorizationEndpoint = Uri.parse(
      'https://accounts.google.com/o/oauth2/auth?access_type=offline'
      '&approval_prompt=force');

  /// The URL from which the pub client will request an access token once it's
  /// been authorized by the user.
  Uri _tokenEndpoint = Uri.parse(
      'https://accounts.google.com/o/oauth2/token');
  Uri get tokenEndpoint => _tokenEndpoint;

  /// The OAuth2 scopes that the pub client needs. Currently the client only needs
  /// the user's email so that the server can verify their identity.
  List _scopes = ['https://www.googleapis.com/auth/userinfo.email'];
  List<String> _request_visible_actions;

  /// An in-memory cache of the user's OAuth2 credentials. This should always be
  /// the same as the credentials file stored in the system cache.
  Credentials _credentials;
  Credentials get credentials => _credentials;

  /// Url to redirect when authorization has been called
  final String authorizedRedirect;

  final String credentialsFilePath;

  /// The port that should be used for the one-shot authorization response
  /// server
  final int authorizationResponseServerPort;

  PubHttpClient _httpClient;

  OAuth2Console({String identifier: null, String secret: null,
    Uri authorizationEndpoint: null, Uri tokenEndpoint: null, List scopes: null,
    List<String> request_visible_actions: null,
    this.authorizedRedirect: 'https://github.com/dart-gde/dart-google-oauth2-library',
    this.credentialsFilePath: 'credentials.json',
    this.authorizationResponseServerPort: 0}) {

    if (identifier != null) this._identifier = identifier;
    if (secret != null) this._secret = secret;
    if (authorizationEndpoint != null) this._authorizationEndpoint = authorizationEndpoint;
    if (tokenEndpoint != null) this._tokenEndpoint = tokenEndpoint;
    if (scopes != null) this._scopes = scopes;
    if (request_visible_actions != null) this._request_visible_actions = request_visible_actions;

    _httpClient = new PubHttpClient();
    _httpClient.tokenEndpoint = tokenEndpoint;
  }

  /// Delete the cached credentials, if they exist.
  void clearCredentials() {
    _credentials = null;
    if (entryExists(credentialsFilePath)) deleteEntry(credentialsFilePath);
  }

  /// Close the httpClient when were done.
  void close() {
    _httpClient.inner.close();
  }

  /// Asynchronously passes an OAuth2 [Client] to [fn], and closes the client when
  /// the [Future] returned by [fn] completes.
  ///
  /// This takes care of loading and saving the client's credentials, as well as
  /// prompting the user for their authorization. It will also re-authorize and
  /// re-run [fn] if a recoverable authorization error is detected.
  Future withClient(Future fn(Client client)) {

    return _getClient().then((client) {
      _credentials = client.credentials;
      return fn(client).whenComplete(() {
        client.close();
        // Be sure to save the credentials even when an error happens.
        _saveCredentials(client.credentials);
      });
    }).catchError((error) {
      if (error is ExpirationException) {
        log.error("Authorization to upload packages has expired and "
        "can't be automatically refreshed.");
        return withClient(fn);
      } else if (error is AuthorizationException) {
        var message = "OAuth2 authorization failed";
        if (error.description != null) {
          message = "$message (${error.description})";
        }
        log.error("$message.");
        clearCredentials();
        return withClient(fn);
      } else {
        throw error;
      }
    });
  }

  Future<Client> _getClient() {
    return new Future.sync(() {
      var credentials = _loadCredentials();
      if (credentials == null) return _authorize();

      var client = new Client(_identifier, _secret, credentials,
          httpClient: _httpClient);
      _saveCredentials(client.credentials);
      return client;
    });
  }

  /// Loads the user's OAuth2 credentials from the in-memory cache or the
  /// filesystem if possible. If the credentials can't be loaded for any reason,
  /// the returned [Future] will complete to null.
  Credentials _loadCredentials() {
    log.fine('Loading OAuth2 credentials.');

    try {
      if (_credentials != null) return _credentials;

      if (!fileExists(credentialsFilePath)) return null;

      var credentials = new Credentials.fromJson(readTextFile(credentialsFilePath));
      if (credentials.isExpired && !credentials.canRefresh) {
        log.error("Authorization has expired and "
        "can't be automatically refreshed.");
        return null; // null means re-authorize.
      }

      return credentials;
    } catch (e) {
      log.error('Warning: could not load the saved OAuth2 credentials: $e\n'
      'Obtaining new credentials...', e);
      return null; // null means re-authorize.
    }
  }

  /// Save the user's OAuth2 credentials to the in-memory cache and the
  /// filesystem.
  void _saveCredentials(Credentials credentials) {
    log.fine('Saving OAuth2 credentials.');
    _credentials = credentials;
    ensureDir(path.dirname(credentialsFilePath));
    writeTextFile(credentialsFilePath, credentials.toJson(), dontLogContents: true);
  }

  /// Gets the user to authorize pub as a client of pub.dartlang.org via oauth2.
  /// Returns a Future that will complete to a fully-authorized [Client].
  Future _authorize() {
    var grant = new AuthorizationCodeGrant(
        _identifier,
        _secret,
        _authorizationEndpoint,
        tokenEndpoint,
        httpClient: _httpClient);

    // Spin up a one-shot HTTP server to receive the authorization code from the
    // Google OAuth2 server via redirect. This server will close itself as soon as
    // the code is received.
    return HttpServer.bind('127.0.0.1', authorizationResponseServerPort).then((server) {
      var authUrl = grant.getAuthorizationUrl(
          Uri.parse('http://localhost:${server.port}'), scopes: _scopes);

      log.message(
          'Need your authorization to access scopes ${_scopes} on your behalf.\n'
          'In a web browser, go to $authUrl\n'
          'Then click "Allow access".\n\n'
      'Waiting for your authorization...');
      return server.first.then((request) {
        var response = request.response;
        if (request.uri.path == "/") {
          log.message('Authorization received, processing...');
          var queryString = request.uri.query;
          if (queryString == null) queryString = '';
          response.statusCode = 302;
          response.headers.set('location', authorizedRedirect);
          response.close();
          return grant.handleAuthorizationResponse(queryToMap(queryString))
              .then((client) {
                server.close();
                return client;
              });
        } else {
          response.statusCode = 404;
          response.close();
        }
      });
    })
    .then((client) {
      log.message('Successfully authorized.\n');
      return client;
    });
  }
}

/**
 * A simple OAuth2 authentication client when [secret] and [accessToken]
 * are already available. [credentials] are kept in memory.
 */
class SimpleOAuth2Console implements OAuth2Console {
  /// The URL from which the pub client will request an access token once it's
  /// been authorized by the user.
  Uri _tokenEndpoint = Uri.parse('https://accounts.google.com/o/oauth2/token');
  Uri get tokenEndpoint => _tokenEndpoint;

  Credentials _credentials;

  Credentials get credentials => _credentials;

  void set credentials(value) {
    _credentials = value;
  }

  String _identifier;

  String _secret;

  String _accessToken;

  final int authorizationResponseServerPort = null;

  Client _simpleHttpClient;

  SimpleOAuth2Console(this._identifier, this._secret, this._accessToken) {
    this.credentials = new Credentials(_accessToken);
  }

  Future withClient(Future fn(Client client)) {
    log.fine("withClient(Future ${fn}(Client client))");
    _simpleHttpClient = new Client(_identifier, _secret, _credentials);
    return fn(_simpleHttpClient);
  }

  void close() {
    _simpleHttpClient.close();
  }

  /*
   * Methods and variables not supported by this client.
   */

  void clearCredentials() {
    throw new UnsupportedError("clearCredentials");
  }

  void set authorizedRedirect(String _authorizedRedirect) {
    throw new UnsupportedError("authorizedRedirect");
  }

  String get authorizedRedirect => null;

  String get credentialsFilePath => null;

  void set credentialsFilePath(String _credentialsFilePath) {
    throw new UnsupportedError("credentialsFilePath");
  }

  Future<Client> _getClient() {
    throw new UnsupportedError("_getClient");
  }

  Credentials _loadCredentials() {
    throw new UnsupportedError("_loadCredentials");
  }
  void _saveCredentials(Credentials credentials) {
    throw new UnsupportedError("_saveCredentials");
  }
  Future _authorize() {
    throw new UnsupportedError("_authorize");
  }

  List _scopes;
  Uri _authorizationEndpoint;
  List<String> _request_visible_actions;
  PubHttpClient _httpClient;
}

/**
 * A compute engine oauth2 console client.
 */
class ComputeOAuth2Console implements OAuth2Console {
  Uri _tokenEndpoint =
      Uri.parse('http://metadata/computeMetadata/v1beta1/instance/service-accounts/default/token');
  Uri get tokenEndpoint => _tokenEndpoint;

  Credentials _credentials;

  Credentials get credentials => _credentials;

  void set credentials(value) {
    _credentials = value;
  }

  String _identifier = "";

  String _secret = "";

  String _accessToken = "";

  final int authorizationResponseServerPort = null;

  Client _simpleHttpClient;

  final String projectId;
  final String privateKey;
  final String iss;
  final String scopes;

  ComputeOAuth2Console(this.projectId, {this.privateKey: null, this.iss: null, this.scopes: null});

  Future withClient(Future fn(Client client)) {
    log.fine("withClient(Future ${fn}(Client client))");

    if (this.privateKey == null && this.iss == null && this.scopes == null) {
      _simpleHttpClient = new ComputeEngineClient(projectId);
    } else {
      _simpleHttpClient = new OtherPlatformClient(projectId, privateKey, iss, scopes);
    }

    return fn(_simpleHttpClient);
  }

  void close() {
    _simpleHttpClient.close();
  }

  /*
   * Methods and variables not supported by this client.
   */

  void clearCredentials() {
    throw new UnsupportedError("clearCredentials");
  }

  void set authorizedRedirect(String _authorizedRedirect) {
    throw new UnsupportedError("authorizedRedirect");
  }

  String get authorizedRedirect => null;

  String get credentialsFilePath => null;

  void set credentialsFilePath(String _credentialsFilePath) {
    throw new UnsupportedError("credentialsFilePath");
  }

  Future<Client> _getClient() {
    throw new UnsupportedError("_getClient");
  }

  Credentials _loadCredentials() {
    throw new UnsupportedError("_loadCredentials");
  }
  void _saveCredentials(Credentials credentials) {
    throw new UnsupportedError("_saveCredentials");
  }
  Future _authorize() {
    throw new UnsupportedError("_authorize");
  }

  List _scopes;
  Uri _authorizationEndpoint;
  List<String> _request_visible_actions;
  PubHttpClient _httpClient;
}

class OtherPlatformClient extends http.BaseClient implements Client {
  final String identifier = "";
  final String secret = "";
  final String projectId;
  Credentials get credentials => _credentials;
  Credentials _credentials;
  http.Client _httpClient;

  final String privateKey;
  final String iss;
  final String scopes;

  OtherPlatformClient(this.projectId, this.privateKey, this.iss, this.scopes,
      {http.Client httpClient})
    : _httpClient = httpClient == null ? new http.Client() : httpClient {
    JWTStore.getCurrent().registerKey(iss, privateKey);
  }

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return async.then((_) {
      // TODO(adam): should we configure iat isExpired check?
      return JWTStore.getCurrent().generateJWT(iss, scopes);
    }).then((JWT jwt) {
      request.headers['authorization'] = "Bearer ${jwt.accessToken}";
      return _httpClient.send(request);
    }).then((response) => response);
    // TODO(adam): better error handling similar to client.dart
  }

  Future<Client> refreshCredentials([List<String> newScopes]) {
    return new Future.value();
  }

  void close() {
    if (_httpClient != null) _httpClient.close();
    _httpClient = null;
  }
}

class ComputeEngineClient extends http.BaseClient implements Client {
  final String identifier = "";
  final String secret = "";
  final String projectId;
  Credentials get credentials => _credentials;
  Credentials _credentials;
  http.Client _httpClient;

  Uri _tokenEndpoint =
      Uri.parse('http://metadata/computeMetadata/v1beta1/instance/service-accounts/default/token');

  ComputeEngineClient(this.projectId,
      {http.Client httpClient})
    : _httpClient = httpClient == null ? new http.Client() : httpClient;

  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return async.then((_) {
      // TODO: check if credentials need to be refreshed.
      return refreshCredentials();
    }).then((_) {
      request.headers['Authorization'] = "OAuth ${credentials.accessToken}";
      request.headers['x-goog-api-version'] = "2";
      request.headers['x-goog-project-id'] = "${projectId}";
      return _httpClient.send(request);
    }).then((response) {
      return response;
    });
  }

  // TODO: use a token store instead of fetching each time. Checkout JWTStore.
  Future<Client> refreshCredentials([List<String> newScopes]) {
    return async.then((_) {
      return _httpClient.get(_tokenEndpoint,
          headers: {'X-Google-Metadata-Request': 'True'});
    }).then((http.Response response) {
      if (response.statusCode == 200) {
        // Successful request
        var tokenData = JSON.decode(response.body);
        int expiresIn = tokenData["expires_in"];
        var expiresTime = new DateTime.now();
        expiresTime = expiresTime.add(new Duration(seconds: expiresIn));
        _credentials = new Credentials(tokenData["access_token"], null, null,
            null, expiresTime);
        return this;
      } else {
        // Unsuccessful request
        throw new StateError("status code = ${response.statusCode}");
      }
    });
  }

  void close() {
    if (_httpClient != null) _httpClient.close();
    _httpClient = null;
  }
}

/// Returns a [Future] that asynchronously completes to `null`.
Future get async => new Future.delayed(const Duration(milliseconds: 0),
                                       () => null);