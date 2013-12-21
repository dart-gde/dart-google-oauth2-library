import "dart:async";
import "package:google_oauth2_client/google_oauth2_console.dart";
import "package:http/http.dart" as http;

void main(args) {
  print("project = ${args[0]}");
  ComputeOAuth2Console computeEngineClient = new ComputeOAuth2Console(args[0]);

  computeEngineClient.withClient(_clientCallback)
    .then((_) {
      print('done');
      computeEngineClient.close();
    });
}

Future _clientCallback(http.Client client) {
  final url = "https://storage.googleapis.com";
  return client.get(url).then((http.Response response) {
    var data = response.body;
    var c = "data = ${data}";
    print(c);
    return c;
  });
}