import "dart:async";
import "dart:json" as JSON;
import "package:google_oauth2_client/google_oauth2_console.dart";
import "package:http/http.dart" as http;

void main() {
  String identifier = "299615367852-n0kfup30mfj5emlclfgud9g76itapvk9.apps.googleusercontent.com";
  String secret = "azeFTOjszzL57dvMd-JS2Zda";
  List scopes = ["https://www.googleapis.com/auth/plus.login"];
  List request_visible_actions = ["http://schemas.google.com/AddActivity", "http://schemas.google.com/CreateActivity"];
  var auth = new OAuth2Console(identifier: identifier, secret: secret, scopes: scopes, request_visible_actions: request_visible_actions);

  Future clientCallback(http.Client client) {
    var completer = new Completer();
    final url = "https://www.googleapis.com/plus/v1/people/me";
    client.get(url).then((http.Response response) {
      var data = JSON.parse(response.body);
      var c = "Logged in as ${data["displayName"]}";
      print(c);
      completer.complete(c);
    });
    return completer.future;
  };

  auth.withClient(clientCallback).whenComplete(() {
    print("done");
    auth.close();
//    auth = null;
// Try for a second time.
//    auth = new OAuth2Console(identifier: identifier, secret: secret, scopes: scopes);
//    auth.withClient(clientCallback).whenComplete(() {
//      print("done2");
//      auth.close();
//      auth = null;
//    });
  });

}