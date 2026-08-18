import 'dart:io';

import 'run_aborted.dart';

/// Resolves the dependencies of the package at [root]; [label] names that
/// root in the abort message when `dart pub get` fails.
Future<void> pubGet(String root, {required String label}) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'pub',
    'get',
  ], workingDirectory: root);
  if (result.exitCode != 0) {
    throw RunAborted(
      'pub get failed in $label:\n${result.stdout}${result.stderr}',
    );
  }
}
