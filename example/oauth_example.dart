import 'dart:async';
import "dart:html";
import "dart:convert";

import "package:google_oauth2_client/google_oauth2_browser.dart";

final ButtonElement loginButton = querySelector("#login");
final logoutButton = querySelector("#logout");
final outputDiv = querySelector("#output");
final DivElement loginWrapper = querySelector("#login_wrapper");
final SelectElement approvalPromptInput = querySelector("#approval_prompt");
final SelectElement immediateInput = querySelector("#immediate");
final SelectElement onlyLoadTokenInput = querySelector("#onlyLoadToken");

void main() {
  // use your own Client ID from the API Console here
  final auth = new GoogleOAuth2(
      "796343192238.apps.googleusercontent.com",
      ["https://www.googleapis.com/auth/books"]);

  outputDiv.innerHtml = "";
  
  loginButton.onClick.listen((e) {
    outputDiv.innerHtml = "Loading...";
    loginButton.disabled = true;
    String approvalPrompt = approvalPromptInput.value;
    if (approvalPrompt.isEmpty) {
      approvalPrompt = null;
    }
    auth.approval_prompt = approvalPrompt;
    bool isImmediate = (immediateInput.value == "1");
    bool onlyLoadToken = (onlyLoadTokenInput.value == "1");
    auth.login(immediate: isImmediate, onlyLoadToken: onlyLoadToken)
      .then(_oauthReady)
      .whenComplete(() {
        loginButton.disabled = false;
      })
      .catchError((e) {
        outputDiv.innerHtml = e.toString();
        print("$e");
      });
  });

  logoutButton.onClick.listen((e) {
    auth.logout();
    loginWrapper.style.display = "inline-block";
    logoutButton.style.display = "none";
    outputDiv.innerHtml = "";
  });
}


Future _oauthReady(Token token) {
  loginWrapper.style.display = "none";
  logoutButton.style.display = "inline-block";
  final url = "https://www.googleapis.com/books/v1/volumes/zyTCAlFPjgYC";

  var headers = getAuthorizationHeaders(token.type, token.data);

  return HttpRequest.request(url, requestHeaders: headers)
    .then((HttpRequest request) {
      if (request.status == 200) {
        var data = JSON.decode(request.responseText);
        outputDiv.innerHtml = """
        <p>Book title: ${data['volumeInfo']['title']}</p>
        <p>Description:<br> ${data['volumeInfo']['description']}</p>
        """;
      } else {
        outputDiv.innerHtml = "Error ${request.status}: ${request.statusText}";
      }
    });
}
