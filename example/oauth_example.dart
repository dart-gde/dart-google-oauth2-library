import 'dart:async';
import "dart:html";
import "dart:convert";

import "package:google_oauth2_client/google_oauth2_browser.dart";

final ButtonElement loginButton = querySelector("#login");
final logoutButton = querySelector("#logout");
final outputDiv = querySelector("#output");
final DivElement loginWrapper = querySelector("#login_wrapper");
final SelectElement approvalPromptInput = querySelector("#approval_prompt");

void main() {
  // use your own Client ID from the API Console here
  final auth = new GoogleOAuth2(
      "796343192238.apps.googleusercontent.com",
      ["https://www.googleapis.com/auth/books"]);

  loginButton.onClick.listen((e) {
    loginButton.disabled = true;
    String approvalPrompt = approvalPromptInput.value;
    if (approvalPrompt.isEmpty) {
      approvalPrompt = null;
    }
    auth.approval_prompt = approvalPrompt;
    auth.login()
      .then(_oauthReady)
      .whenComplete(() {
        loginButton.disabled = false;
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
        outputDiv.innerHtml = "Book info:\n${data['volumeInfo']['title']}";
      } else {
        outputDiv.innerHtml = "Error ${request.status}: ${request.statusText}";
      }
    });
}
