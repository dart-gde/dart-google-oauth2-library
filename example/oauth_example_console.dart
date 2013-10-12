import "dart:async";
import "dart:convert";
import "package:google_oauth2_client/google_oauth2_console.dart";
import "package:http/http.dart" as http;

const _IDENTIFIER =
  "299615367852-n0kfup30mfj5emlclfgud9g76itapvk9.apps.googleusercontent.com";
const _SECRET = "azeFTOjszzL57dvMd-JS2Zda";
const _SCOPES = const ["https://www.googleapis.com/auth/plus.login"];
const _REQUEST_VISIBLE_ACTIONS = const[
        "http://schemas.google.com/AddActivity",
        "http://schemas.google.com/CreateActivity"];

void main() {
  var auth = new OAuth2Console(identifier: _IDENTIFIER,
      secret: _SECRET,
      scopes: _SCOPES,
      request_visible_actions: _REQUEST_VISIBLE_ACTIONS);

  auth.withClient(_clientCallback)
    .then((_) {
      print('done');
      auth.close();
    });
}

Future _clientCallback(http.Client client) {
  final url = "https://www.googleapis.com/plus/v1/people/me";
  return client.get(url).then((http.Response response) {
    var data = JSON.decode(response.body);
    var c = "Logged in as ${data["displayName"]}";
    print(c);
    return c;
  });
}
