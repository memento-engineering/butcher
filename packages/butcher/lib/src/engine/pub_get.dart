import 'dart:io';

import 'run_aborted.dart';

/// Resolves the dependencies of the package at [root]; [label] names that
/// root in the abort message when `pub get` fails. A Flutter package resolves
/// through its [flutter] command, which knows where the Flutter SDK lives.
Future<void> pubGet(
  String root, {
  required String label,
  String? flutter,
}) async {
  final result = await Process.run(flutter ?? Platform.resolvedExecutable, [
    'pub',
    'get',
  ], workingDirectory: root);
  if (result.exitCode != 0) {
    throw RunAborted(
      'pub get failed in $label:\n${result.stdout}${result.stderr}',
    );
  }
}
