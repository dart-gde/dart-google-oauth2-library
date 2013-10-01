part of google_oauth2_browser;

/**
 *  A simple OAuth2 authentication context which can use if you already have a [token]
 *  via another mechanism, like f.e. the Chrome Extension Identity API
 */
class SimpleOAuth2 extends OAuth2<String> {
  final String token;
  final String tokenType;

  /// Creates an OAuth2 context for the application using [token] for authentication
  SimpleOAuth2(String this.token, {String this.tokenType: "Bearer"}) : super();

  Future ensureAuthenticated() => new Future.value();

  Map<String, String> getAuthHeaders() =>
      getAuthorizationHeaders(tokenType, token);
}
