import 'dart:io';

import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

/// Creates a fully isolated filesystem context for one test.
Future<ButcherPaths> isolatedButcherPaths(String prefix) async {
  final root = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() => root.delete(recursive: true));
  return ButcherPaths(root: root.path);
}
