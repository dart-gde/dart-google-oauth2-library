import "dart:async";
import "dart:convert";
import "../lib/google_oauth2_console.dart";
import "package:http/http.dart" as http;

const _IDENTIFIER =
  "299615367852-n0kfup30mfj5emlclfgud9g76itapvk9.apps.googleusercontent.com";
const _SECRET = "azeFTOjszzL57dvMd-JS2Zda";
const _SCOPES = const ["https://www.googleapis.com/auth/plus.login"];
const _REQUEST_VISIBLE_ACTIONS = const[
        "http://schemas.google.com/AddActivity",
        "http://schemas.google.com/CreateActivity"];

void main() {
  //This should create the client with the default timeout, since no params are given
  testTimeoutInterval(). //ne value given, it will go with the default value
  then((_){
    return testTimeoutInterval(timeoutInterval:0); //no timeout at all
  }).catchError((error){
    print("we encountered an error. up until here, that shouldn't happen");  
  }).
  then((_){
    return testTimeoutInterval(timeoutInterval:1); //a timeoutInterval of 1 second will make it fail almost certainly 
  }).catchError((error){
    print("ERROR: if this is the only error message, this piece works");
  });
}

Future testTimeoutInterval({int timeoutInterval}){
  var auth = new OAuth2Console(identifier: _IDENTIFIER,
      secret: _SECRET,
      scopes: _SCOPES,
      request_visible_actions: _REQUEST_VISIBLE_ACTIONS,
      timeoutInterval: timeoutInterval);

  return auth.withClient(_clientCallback)
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
