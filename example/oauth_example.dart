import "dart:html";
import "dart:json";
import "package:dart_google_oauth2_library/oauth2.dart";

void main() {
  final loginButton = query("#login");
  final logoutButton = query("#logout");
  final outputDiv = query("#output");

  void oauthReady(Token token) {
    loginButton.style.display = "none";
    logoutButton.style.display = "inline-block";
    var request = new HttpRequest();
    final url = "https://www.googleapis.com/plus/v1/people/me";

    request.on.loadEnd.add((Event e) {
      if (request.status == 200) {
        var data = JSON.parse(request.responseText);
        outputDiv.innerHtml = "Logged in as ${data["displayName"]}";
      } else {
        outputDiv.innerHtml = "Error ${request.status}: ${request.statusText}";
      }
    });

    request.open("GET", url);
    request.setRequestHeader("Authorization", "${token.type} ${token.data}");
    request.send();
  }

  // use your own Client ID from the API Console here
  final auth = new OAuth2(
      "796343192238.apps.googleusercontent.com",
      ["https://www.googleapis.com/auth/plus.me"],
      tokenLoaded:oauthReady);

  loginButton.on.click.add((e) => auth.login());
  logoutButton.on.click.add((e) {
    auth.logout();
    loginButton.style.display = "inline-block";
    logoutButton.style.display = "none";
    outputDiv.innerHtml = "";
  });
}

