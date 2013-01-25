// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library curl_client;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'io.dart';
import 'log.dart' as log;
import 'utils.dart';

/// A drop-in replacement for [http.Client] that uses the `curl` command-line
/// utility rather than [dart:io] to make requests. This class will only exist
/// temporarily until [dart:io] natively supports requests over HTTPS.
class CurlClient extends http.BaseClient {
  /// The path to the `curl` executable to run.
  ///
  /// By default on Unix-like operating systems, this will look up `curl` on the
  /// system path. On Windows, it will use the bundled `curl.exe`.
  final String executable;

  /// Creates a new [CurlClient] with [executable] as the path to the `curl`
  /// executable.
  ///
  /// By default on Unix-like operating systems, this will look up `curl` on the
  /// system path. On Windows, it will use the bundled `curl.exe`.
  CurlClient([String executable])
    : executable = executable == null ? _defaultExecutable : executable;

  /// Sends a request via `curl` and returns the response.
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    log.fine("Sending Curl request $request");

    var requestStream = request.finalize();
    return withTempDir((tempDir) {
      var headerFile = join(tempDir, "curl-headers");
      var arguments = _argumentsForRequest(request, headerFile);
      var process;
      return startProcess(executable, arguments).then((process_) {
        process = process_;
        return requestStream.pipe(wrapOutputStream(process.stdin));
      }).then((_) {
        return _waitForHeaders(process, expectBody: request.method != "HEAD");
      }).then((_) => new File(headerFile).readAsLines())
        .then((lines) => _buildResponse(request, process, lines));
    });
  }

  /// Returns the list of arguments to `curl` necessary for performing
  /// [request]. [headerFile] is the path to the file where the response headers
  /// should be stored.
  List<String> _argumentsForRequest(
      http.BaseRequest request, String headerFile) {
    // Note: This line of code gets munged by create_sdk.py to be the correct
    // relative path to the certificate file in the SDK.
    var pathToCertificates = "ca-certificates.crt";

    var arguments = ["--dump-header", headerFile];

    var certFile = new File(pathToCertificates);
    if (certFile.existsSync()) {
      arguments.add("--cacert");
      arguments.add(pathToCertificates);
    } else {
      log.warning("Calling curl with --insecure, $pathToCertificates not found.");
      arguments.add("--insecure");
    }

    if (request.method == 'HEAD') {
      arguments.add("--head");
    } else {
      arguments.add("--request");
      arguments.add(request.method);
    }
    if (request.followRedirects) {
      arguments.add("--location");
      arguments.add("--max-redirs");
      arguments.add(request.maxRedirects.toString());
    }
    if (request.contentLength != 0)  {
      arguments.add("--data-binary");
      arguments.add("@-");
    }

    // Override the headers automatically added by curl. We want to make it
    // behave as much like the dart:io client as possible.
    var headers = {
      'accept': '',
      'user-agent': ''
    };
    request.headers.forEach((name, value) => headers[name] = value);
    if (request.contentLength < 0) {
      headers['content-length'] = '';
      headers['transfer-encoding'] = 'chunked';
    } else if (request.contentLength > 0) {
      headers['content-length'] = request.contentLength.toString();
    }

    headers.forEach((name, value) {
      arguments.add("--header");
      arguments.add("$name: $value");
    });
    arguments.add(request.url.toString());

    return arguments;
  }

  /// Returns a [Future] that completes once the `curl` [process] has finished
  /// receiving the response headers. [expectBody] indicates that the server is
  /// expected to send a response body (which is not the case for HEAD
  /// requests).
  ///
  /// Curl prints the headers to a file and then prints the body to stdout. So,
  /// in theory, we could read the headers as soon as we see anything appear
  /// in stdout. However, that seems to be too early to successfully read the
  /// file (at least on Mac). Instead, this just waits until the entire process
  /// has completed.
  Future _waitForHeaders(Process process, {bool expectBody}) {
    var completer = new Completer();
    process.onExit = (exitCode) {
      log.io("Curl process exited with code $exitCode.");

      if (exitCode == 0) {
        completer.complete(null);
        return;
      }

      chainToCompleter(consumeInputStream(process.stderr).then((stderrBytes) {
        var message = new String.fromCharCodes(stderrBytes);
        log.fine('Got error reading headers from curl: $message');
        if (exitCode == 47) {
          throw new RedirectLimitExceededException([]);
        } else {
          throw new HttpException(message);
        }
      }), completer);
    };

    // If there's not going to be a response body (e.g. for HEAD requests), curl
    // prints the headers to stdout instead of the body. We want to wait until
    // all the headers are received to read them from the header file.
    if (!expectBody) {
      return Future.wait([
        consumeInputStream(process.stdout),
        completer.future
      ]);
    }

    return completer.future;
  }

  /// Returns a [http.StreamedResponse] from the response data printed by the
  /// `curl` [process]. [lines] are the headers that `curl` wrote to a file.
  http.StreamedResponse _buildResponse(
      http.BaseRequest request, Process process, List<String> lines) {
    // When curl follows redirects, it prints the redirect headers as well as
    // the headers of the final request. Each block is separated by a blank
    // line. We just care about the last block. There is one trailing empty
    // line, though, which we don't want to consider a separator.
    var lastBlank = lines.lastIndexOf("", lines.length - 2);
    if (lastBlank != -1) lines.removeRange(0, lastBlank + 1);

    var statusParts = lines.removeAt(0).split(" ");
    var status = int.parse(statusParts[1]);
    var isRedirect = status >= 300 && status < 400;
    var reasonPhrase =
        Strings.join(statusParts.getRange(2, statusParts.length - 2), " ");
    var headers = {};
    for (var line in lines) {
      if (line.isEmpty) continue;
      var split = split1(line, ":");
      headers[split[0].toLowerCase()] = split[1].trim();
    }
    var responseStream = process.stdout;
    if (responseStream.closed) {
      responseStream = new ListInputStream();
      responseStream.markEndOfStream();
    }
    var contentLength = -1;
    if (headers.containsKey('content-length')) {
      contentLength = int.parse(headers['content-length']);
    }

    return new http.StreamedResponse(
        wrapInputStream(responseStream), status, contentLength,
        request: request,
        headers: headers,
        isRedirect: isRedirect,
        reasonPhrase: reasonPhrase);
  }

  /// The default executable to use for running curl. On Windows, this is the
  /// path to the bundled `curl.exe`; elsewhere, this is just "curl", and we
  /// assume it to be installed and on the user's PATH.
  static String get _defaultExecutable {
    if (Platform.operatingSystem != 'windows') return 'curl';
    // Note: This line of code gets munged by create_sdk.py to be the correct
    // relative path to curl in the SDK.

    throw "Windows is not supported yet";
    var pathToCurl = "../../third_party/curl/curl.exe";
    return relativeToPub(pathToCurl);
  }
}
