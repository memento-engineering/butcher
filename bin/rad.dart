import 'dart:io';

import 'package:radioactive_dart/src/cli/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await radMain(arguments);
}
