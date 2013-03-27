import "dart:html";
import "dart:json" as JSON;
import "package:google_oauth2_client/google_oauth2_browser.dart";

void main() {
  final loginButton = query("#login");
  final logoutButton = query("#logout");
  final outputDiv = query("#output");

  void oauthReady(Token token) {

    var testOAuth = new SimpleOAuth2(token.data);
    
    loginButton.style.display = "none";
    logoutButton.style.display = "inline-block";
    var request = new HttpRequest();
    final url = "https://www.googleapis.com/plus/v1/people/me";

    request.onLoadEnd.listen((Event e) {
      if (request.status == 200) {
        var data = JSON.parse(request.responseText);
        outputDiv.innerHtml = "Logged in as ${data["displayName"]}";
      } else {
        outputDiv.innerHtml = "Error ${request.status}: ${request.statusText}";
      }
    });

    request.open("GET", url);
    testOAuth.authenticate(request).then((request) => request.send());
    
    //request.setRequestHeader("Authorization", "${token.type} ${token.data}");
    //request.send();
  }

  // use your own Client ID from the API Console here
  final auth = new GoogleOAuth2(
      "796343192238.apps.googleusercontent.com",
      ["https://www.googleapis.com/auth/plus.login"],
      request_visible_actions: ["http://schemas.google.com/AddActivity", "http://schemas.google.com/CreateActivity"],
      tokenLoaded: oauthReady);

  loginButton.onClick.listen((e) => auth.login());
  logoutButton.onClick.listen((e) {
    auth.logout();
    loginButton.style.display = "inline-block";
    logoutButton.style.display = "none";
    outputDiv.innerHtml = "";
  });
}

