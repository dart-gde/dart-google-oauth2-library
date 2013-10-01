part of google_oauth2_browser;

/// An OAuth2 authentication context.
abstract class OAuth2<T> {

  T get token;

  OAuth2();

  /**
   * Take a [request] and return the request with the authorization headers set correctly
   */
  Future<HttpRequest> authenticate(HttpRequest request);
}
