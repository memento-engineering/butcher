import 'dart:io';

import 'package:butcher/src/cli/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await radMain(arguments);
}
