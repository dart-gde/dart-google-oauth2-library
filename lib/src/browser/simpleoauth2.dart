part of google_oauth2_browser;

/**
 *  A simple OAuth2 authentication context which can use if you already have a [token]
 *  via another mechanism, like f.e. the Chrome Extension Identity API
 */
class SimpleOAuth2 extends OAuth2 {
  String token;
  String tokenType;

  /// Creates an OAuth2 context for the application using [token] for authentication
  SimpleOAuth2(String this.token, {String this.tokenType: "Bearer"}) : super();

  Future<HttpRequest> authenticate(HttpRequest request) {
    request.setRequestHeader("Authorization", "${tokenType} ${token}");
    return new Future.immediate(request); 
  }
}