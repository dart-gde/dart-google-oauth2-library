// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library oauth2;

import 'dart:async';

import 'package:oauth2/oauth2.dart';
import 'package:path/path.dart' as path;

import 'http.dart';
import 'io.dart';
import 'log.dart' as log;
import 'safe_http_server.dart';
import 'system_cache.dart';
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
  String _authorizedRedirect = 'https://github.com/dart-gde/dart-google-oauth2-library';

  SystemCache _systemCache;
  SystemCache get systemCache => _systemCache;
  String _credentialsFileName = "credentials.json";

  PubHttpClient _httpClient;

  OAuth2Console({String identifier: null, String secret: null,
    Uri authorizationEndpoint: null, Uri tokenEndpoint: null, List scopes: null,
    List<String> request_visible_actions: null,
    String authorizedRedirect: 'https://github.com/dart-gde/dart-google-oauth2-library',
    String credentialsFileName: 'credentials.json', SystemCache systemCache: null}) {

    if (identifier != null) this._identifier = identifier;
    if (secret != null) this._secret = secret;
    if (authorizationEndpoint != null) this._authorizationEndpoint = authorizationEndpoint;
    if (tokenEndpoint != null) this._tokenEndpoint = tokenEndpoint;
    if (scopes != null) this._scopes = scopes;
    if (request_visible_actions != null) this._request_visible_actions = request_visible_actions;

    if (credentialsFileName != null) this._credentialsFileName = credentialsFileName;

    if (systemCache != null) {
      _systemCache = systemCache;
    } else {
      _systemCache = new SystemCache(".");
    }

    this._authorizedRedirect = authorizedRedirect;

    _httpClient = new PubHttpClient();
    _httpClient.tokenEndpoint = tokenEndpoint;
  }

  /// Delete the cached credentials, if they exist.
  void clearCredentials(SystemCache cache) {
    _credentials = null;
    var credentialsFile = _credentialsFile(cache);
    if (entryExists(credentialsFile)) deleteEntry(credentialsFile);
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

    return _getClient(_systemCache).then((client) {
      var completer = new Completer();
      _credentials = client.credentials;
      return fn(client).whenComplete(() {
        client.close();
        // Be sure to save the credentials even when an error happens.
        _saveCredentials(_systemCache, client.credentials);
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
        clearCredentials(_systemCache);
        return withClient(fn);
      } else {
        throw error;
      }
    });
  }

  /// Gets a new OAuth2 client. If saved credentials are available, those are
  /// used; otherwise, the user is prompted to authorize the pub client.
//  Future _getClient(SystemCache cache) {
//    return defer(() {
//      var credentials = _loadCredentials(cache);
//      if (credentials == null) return _authorize();
//
//      var client = new Client(_identifier, _secret, credentials,
//          httpClient: _httpClient);
//      _saveCredentials(cache, client.credentials);
//      return client;
//    });
//  }

  Future<Client> _getClient(SystemCache cache) {
    return new Future.sync(() {
      var credentials = _loadCredentials(cache);
      if (credentials == null) return _authorize();

      var client = new Client(_identifier, _secret, credentials,
          httpClient: _httpClient);
      _saveCredentials(cache, client.credentials);
      return client;
    });
  }

  /// Loads the user's OAuth2 credentials from the in-memory cache or the
  /// filesystem if possible. If the credentials can't be loaded for any reason,
  /// the returned [Future] will complete to null.
  Credentials _loadCredentials(SystemCache cache) {
    log.fine('Loading OAuth2 credentials.');

    try {
      if (_credentials != null) return _credentials;

      var path = _credentialsFile(cache);
      if (!fileExists(path)) return null;

      var credentials = new Credentials.fromJson(readTextFile(path));
      if (credentials.isExpired && !credentials.canRefresh) {
        log.error("Authorization has expired and "
        "can't be automatically refreshed.");
        return null; // null means re-authorize.
      }

      return credentials;
    } catch (e) {
      log.error('Warning: could not load the saved OAuth2 credentials: $e\n'
      'Obtaining new credentials...');
      return null; // null means re-authorize.
    }
  }

  /// Save the user's OAuth2 credentials to the in-memory cache and the
  /// filesystem.
  void _saveCredentials(SystemCache cache, Credentials credentials) {
    log.fine('Saving OAuth2 credentials.');
    _credentials = credentials;
    var credentialsPath = _credentialsFile(cache);
    ensureDir(path.dirname(credentialsPath));
    writeTextFile(credentialsPath, credentials.toJson(), dontLogContents: true);
  }

  /// The path to the file in which the user's OAuth2 credentials are stored.
  String _credentialsFile(SystemCache cache) =>
      path.join(cache.rootDir, 'credentials.json');

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
    return SafeHttpServer.bind('127.0.0.1', 0).then((server) {
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
          response.headers.set('location', _authorizedRedirect);
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