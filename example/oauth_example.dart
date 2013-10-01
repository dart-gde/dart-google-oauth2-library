import "dart:html";
import "dart:json" as JSON;
import "package:google_oauth2_client/google_oauth2_browser.dart";

final loginButton = query("#login");
final logoutButton = query("#logout");
final outputDiv = query("#output");

void main() {


  // use your own Client ID from the API Console here
  final auth = new GoogleOAuth2(
      "796343192238.apps.googleusercontent.com",
      ["https://www.googleapis.com/auth/books"],
      tokenLoaded: _oauthReady);

  loginButton.onClick.listen((e) => auth.login());

  logoutButton.onClick.listen((e) {
    auth.logout();
    loginButton.style.display = "inline-block";
    logoutButton.style.display = "none";
    outputDiv.innerHtml = "";
  });
}


void _oauthReady(Token token) {

  var testOAuth = new SimpleOAuth2(token.data);

  loginButton.style.display = "none";
  logoutButton.style.display = "inline-block";
  var request = new HttpRequest();
  final url = "https://www.googleapis.com/books/v1/volumes/zyTCAlFPjgYC";

  request.onLoadEnd.listen((Event e) {
    if (request.status == 200) {
      var data = JSON.parse(request.responseText);
      print(request.responseText);
      outputDiv.innerHtml = "Book info:\n${data['volumeInfo']['title']}";
    } else {
      outputDiv.innerHtml = "Error ${request.status}: ${request.statusText}";
    }
  });

  request.open("GET", url);
  testOAuth.authenticate(request).then((request) => request.send());
}
