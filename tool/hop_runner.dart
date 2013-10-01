library hop_runner;

import 'package:hop/hop.dart';
import 'package:hop/hop_tasks.dart';

void main() {

  final libList = ['lib/google_oauth2_browser.dart', 'lib/google_oauth2_console.dart'];

  addTask('docs', createDartDocTask(libList, linkApi: true));

  addTask('analyze_libs', createAnalyzerTask(libList));

  runHop();
}
