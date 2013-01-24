import "dart:io";
import "dart:async";
import "dart:json" as JSON;
import "package:google_oauth2_client/google_oauth2_console.dart";
import "package:http/http.dart" as http;

void main() {
  showAll();
  String identifier = "299615367852-n0kfup30mfj5emlclfgud9g76itapvk9.apps.googleusercontent.com";
  String secret = "8ini0niNxsDN0y42ye_UNubw";
  List scopes = ["https://www.googleapis.com/auth/plus.me"];
  final auth = new OAuth2Console(identifier: identifier, secret: secret, scopes: scopes);

  Future clientCallback(http.Client client) {
    var completer = new Completer();
    final url = "https://www.googleapis.com/plus/v1/people/me";
    client.get(url).then((http.Response response) {
      var data = JSON.parse(response.body);
      print("Logged in as ${data["displayName"]}");
    });
    return completer.future;
  };

  auth.withClient(new SystemCache("."), clientCallback);
}