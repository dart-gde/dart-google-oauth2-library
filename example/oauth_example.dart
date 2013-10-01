import 'dart:async';
import "dart:html";
import "dart:json" as JSON;
import "package:google_oauth2_client/google_oauth2_browser.dart";

final ButtonElement loginButton = query("#login");
final logoutButton = query("#logout");
final outputDiv = query("#output");

void main() {

  // use your own Client ID from the API Console here
  final auth = new GoogleOAuth2(
      "796343192238.apps.googleusercontent.com",
      ["https://www.googleapis.com/auth/books"]);

  loginButton.onClick.listen((e) {
    loginButton.disabled = true;
    auth.login()
      .then(_oauthReady)
      .whenComplete(() {
        loginButton.disabled = false;
      });
  });

  logoutButton.onClick.listen((e) {
    auth.logout();
    loginButton.style.display = "inline-block";
    logoutButton.style.display = "none";
    outputDiv.innerHtml = "";
  });
}


Future _oauthReady(Token token) {

  loginButton.style.display = "none";
  logoutButton.style.display = "inline-block";
  final url = "https://www.googleapis.com/books/v1/volumes/zyTCAlFPjgYC";

  var headers = getAuthorizationHeaders(token.type, token.data);

  return HttpRequest.request(url, requestHeaders: headers)
    .then((HttpRequest request) {
      if (request.status == 200) {
        var data = JSON.parse(request.responseText);
        outputDiv.innerHtml = "Book info:\n${data['volumeInfo']['title']}";
      } else {
        outputDiv.innerHtml = "Error ${request.status}: ${request.statusText}";
      }
    });
}
