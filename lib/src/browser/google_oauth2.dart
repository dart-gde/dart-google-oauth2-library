part of google_oauth2_browser;

/// Google OAuth2 authentication context. For more details on how OAuth2 works for client-side, see
/// [Oauth2 client-side authentication](https://developers.google.com/accounts/docs/OAuth2#clientside)
class GoogleOAuth2 extends OAuth2<Token> {
  final String _clientId;
  final List<String> _scopes;
  final List<String> _request_visible_actions;
  final String _provider;
  final String _tokenValidationUri;
  final Function _tokenLoaded;
  final Function _tokenNotLoaded;
  String _approval_prompt;

  Future<_ProxyChannel> _channel;

  /// Destination for not-yet-validated tokens we're waiting to receive over
  /// the proxy channel.
  Completer<Token> _tokenCompleter;

  /// The last fetched token.
  Token __token; // Double-underscore because it has a private setter _token.

  /// Constructor.
  ///
  /// @param provider the URI to provide Google OAuth2 authentication.
  /// @param tokenValidationUri the URI to validate OAuth2 tokens against.
  /// @param clientId Client id for the Google API app. Eg, for Google Books, use
  ///        "796343192238.apps.googleusercontent.com",
  /// @param scopes list of scopes (kinds of information) you are planning to use. For example, to
  ///        get data related to Google Books and user info, use
  ///        `["https://www.googleapis.com/auth/books", "https://www.googleapis.com/auth/userinfo.email"]`
  /// @param tokenLoaded a callback to use when a non-null login token is ready
  /// @param approval_prompt can be null or 'force' to force user approval or 'auto' (default)
  /// @param autoLogin if true, try to login with "immediate" param (no popup will be shown)
  /// @param onlyLoadToken instead of showing user prompt, use stored token (if available)
  GoogleOAuth2(
      String this._clientId,
      List<String> this._scopes,
      { List<String> request_visible_actions: null,
        String provider: "https://accounts.google.com/o/oauth2/",
        String tokenValidationUri: "https://www.googleapis.com/oauth2/v1/tokeninfo",
        tokenLoaded(Token token),
        tokenNotLoaded(),
        bool autoLogin: false,
        bool autoLoadStoredToken: true,
        String approval_prompt: null})
      : _provider = provider,
        _tokenValidationUri = tokenValidationUri,
        _tokenLoaded = tokenLoaded,
        _tokenNotLoaded = tokenNotLoaded,
        _request_visible_actions = request_visible_actions,
        _approval_prompt = approval_prompt,
        super() {
    _channel = _createFutureChannel();

    // Attempt an immediate login, we may already be authorized.
    if (autoLogin) {
      login(immediate: true, onlyLoadToken: false)
          .then((t) => print("Automatic login successful"))
          .catchError((e) => print("Automatic login failed: $e"));
    } else if (autoLoadStoredToken) {
      login(immediate: true, onlyLoadToken: true)
          .then((t) => print("Login with stored token successful"))
          .catchError((e) => print("Failed to login with existing token: $e"));
    }
  }

  Map<String, String> getAuthHeaders() => getAuthorizationHeaders(token.type, token.data);

  /// Sets up the proxy iframe in the provider's origin that will receive
  /// postMessages and relay them to us.
  ///
  /// This completes asynchronously as the proxy iframe is not ready to use
  /// until we've received an 'oauth2relayReady' message from it.
  Future<_ProxyChannel> _createFutureChannel() {
    final channelCompleter = new Completer<_ProxyChannel>();
    _ProxyChannel channel;
    channel = new _ProxyChannel(_provider, (subject, args) {
      switch (subject) {

        // Channel is ready at this point
        case "oauth2relayReady":
          channelCompleter.complete(channel);
          break;
        case "oauth2callback":
          try {
            Token token = Token._parse(args[0]);
            if (!_tokenCompleter.isCompleted) {
              _tokenCompleter.complete(token);
            }
          } catch (exception) {
            if (!_tokenCompleter.isCompleted) {
              _tokenCompleter.completeError(exception);
            }
          }
          break;
      }
    });
    return channelCompleter.future;
  }

  /// Gets the URI that prompts the user for pemission (if required).
  /// 
  /// @param immediate if true, generate a URI to prompt user for permission
  String _getAuthorizeUri(bool immediate) {
    Map<String, String> queryParams = {
      "response_type": "token",
      "client_id": _clientId,
      "origin": window.location.origin,
      "redirect_uri": "postmessage", // Response will post to the proxy iframe
      "scope": _scopes.join(" "),
      "immediate": immediate,
      "approval_prompt": _approval_prompt
    };
    if (_request_visible_actions != null && _request_visible_actions.length > 0) {
      queryParams["request_visible_actions"] = _request_visible_actions.join(" ");
    }
    return UrlPattern.generatePattern("${_provider}auth", {}, queryParams);
  }

  /// Deletes the stored token
  void logout() {
    _token = null;
  }

  /// Attempts to authenticate.
  ///
  /// Scenarios:
  ///
  /// * If you have an existing valid token, it will be immediately returned.
  /// * If you have an expired token, it will be silently renewed (override
  ///   with immediate:true)
  /// * If you have no token, a popup prompt will be displayed.
  /// * If the user declines, closes the popup, or the service returns a token
  ///   that cannot be validated, an exception will be delivered.
  ///   
  /// @param immediate authenticate user with the "immediate" parameter. No popup will be shown.
  /// @param onlyLoadToken instead of showing user prompt, use stored token (if available)
  Future<Token> login({bool immediate: false, bool onlyLoadToken: false}) {
    if ((_approval_prompt == "force") && immediate) {
      return new Future<Token>.error("Can't force approval prompt with immediate login");
    }
    
    if (token != null) {

      // Return the good token right away
      if (!token.expired) {
        return new Future<Token>.value(token);
      }
      
      // Token expired - simply renew it by later making the immedate auth call
      if (immediate == null) {
        immediate = true;
      }
    }

    // Login may already be in progress
    if (_tokenCompleter != null && !_tokenCompleter.isCompleted) { 

      // An in-progress request will satisfy an immediate request
      // (even if it's not immediate).
      if (immediate) {
        return _tokenCompleter.future;
      }

      Completer tokenCompleter = new Completer<Token>();
      _tokenCompleter.future
          .then((value) => tokenCompleter.complete(value))
          .catchError((e) {

            // Ongoing login failed - try to login again
            login(immediate: immediate, onlyLoadToken: onlyLoadToken)
                .then((value) => tokenCompleter.complete(value))
                .catchError((e) => tokenCompleter.completeError(e));
          });
      return tokenCompleter.future;
    }

    // If there is valid locally stored token
    if ((_storedToken != null) && !_storedToken.expired) {
      Completer storedTokenCompleter = new Completer<Token>();
      _storedToken.validate(_clientId, service: _tokenValidationUri)
          .then((bool isValid) {
            if (isValid) {
              _token = _storedToken;
              storedTokenCompleter.complete(_storedToken);
              return;
            }

            _token = null;

            // Stored token not valid - try to log in again
            login(immediate: immediate, onlyLoadToken: onlyLoadToken)
              .then((token) => storedTokenCompleter.complete(token))
              .catchError((e) => storedTokenCompleter.completeError(e));
          })
          .catchError((e) {
            _token = null;

            // Don't prompt user, simply complete with an error
            if (onlyLoadToken) {
              _tokenCompleter.completeError("Locally saved token is not valid");
              return;
            }

            // Try to log in again
            login(immediate: immediate, onlyLoadToken: onlyLoadToken)
                .then((token) => storedTokenCompleter.complete(token))
                .catchError((e) => storedTokenCompleter.completeError(e));
          });
      return storedTokenCompleter.future;
    }

    Completer<Token> tokenCompleter = new Completer();
    tokenCompleter.future.then((token) {
      _token = token;
    }).catchError((e) {
      _token = null;
    });

    _tokenCompleter = _wrapValidation(tokenCompleter);

    // Synchronous if the channel is already open -> avoids popup blocker
    _channel.then((_ProxyChannel value) {
      String uri = _getAuthorizeUri(immediate);

      // Request for immediate authentication
      if (immediate) {
        IFrameElement iframe = _iframe(uri);
        _tokenCompleter.future
          .whenComplete(() => iframe.remove())
          .catchError((e) => print("Failed to login with immediate: $e"));
        return;
      }

      // Prompt user with a popup for user authorization
      WindowBase popup = _popup(uri);
      new _WindowPoller(_tokenCompleter, popup).poll();
    }).catchError((e) {
      _tokenCompleter.completeError(e);
    });

    return _tokenCompleter.future;
  }

  Future ensureAuthenticated() {
    return login().then((_) => null);
  }

  /// Returns the OAuth2 token, if one is currently available.
  Token get token => __token;

  set _token(Token value) {
    final invokeTokenLoadedCallback = (__token == null) && (value != null);
    final invokeTokenNotLoadedCallback = (__token == null) && (value == null);
    try {
      _storedToken = value;
    } catch (e) {
      print("Failed to cache OAuth2 token: $e");
    }
    __token = value;
    if (invokeTokenLoadedCallback && (_tokenLoaded != null)) {
      var timer = new Timer(const Duration(milliseconds: 0), () {
        try {
          _tokenLoaded(value);
        } catch (e) {
          print("Failed to invoke tokenLoaded callback: $e");
        }
      });
    }
    if (invokeTokenNotLoadedCallback && (_tokenNotLoaded != null)) {
      var timer = new Timer(const Duration(milliseconds: 0), () {
        try {
          _tokenNotLoaded();
        } catch (e) {
          print("Failed to invoke tokenNotLoaded callback: $e");
        }
      });
    }
  }

  Token get _storedToken => window.localStorage.containsKey(_storageKey) ? new Token.fromJson(
      window.localStorage[_storageKey]) : null;

  void set _storedToken(Token value) {
    if (value == null) {
      window.localStorage.remove(_storageKey);
    } else {
      window.localStorage[_storageKey] = value.toJson();
    }
  }

  /// Returns a unique identifier for this context for use in localStorage.
  String get _storageKey => JSON.encode({
    "clientId": _clientId,
    "scopes": _scopes,
    "provider": _provider,
  });

  /// Takes a completer that accepts validated tokens, and returns a completer
  /// that accepts unvalidated tokens.
  Completer<Token> _wrapValidation(Completer<Token> validTokenCompleter) {
    Completer<Token> result = new Completer();
    result.future.then((Token token) {
      token.validate(_clientId, service: _tokenValidationUri)
          .then((bool isValid) {
            if (isValid) {
              validTokenCompleter.complete(token);
            } else {
              validTokenCompleter.completeError("Server returned token is invalid");
            }
          })
          .catchError((e) => validTokenCompleter.completeError(e));
    }).catchError((e) => validTokenCompleter.completeError(e));

    return result;
  }
 
  String get approval_prompt => _approval_prompt;

  set approval_prompt(String approval_prompt) {
    this._approval_prompt = approval_prompt;
  }
}
