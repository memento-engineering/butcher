import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'run_aborted.dart';

/// The `flutter` command for the package at [projectRoot], or `null` when the
/// package depends on nothing from the Flutter SDK.
///
/// The command is the one beside the [dart] butcher runs on, which is
/// `<flutter>/bin/cache/dart-sdk/bin/dart` when it is Flutter's own, or else
/// the one under the `FLUTTER_ROOT` in [environment]; never one found on the
/// `PATH` (ADR 0003). Throws [RunAborted] when the package needs Flutter and
/// neither exists.
String? flutterFor(
  String projectRoot, {
  String? dart,
  Map<String, String>? environment,
}) {
  if (!_dependsOnFlutter(projectRoot)) return null;
  final command = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final bundled = p.join(
    p.dirname(
      p.dirname(
        p.dirname(p.dirname(p.dirname(dart ?? Platform.resolvedExecutable))),
      ),
    ),
    'bin',
    command,
  );
  final root = (environment ?? Platform.environment)['FLUTTER_ROOT'];
  for (final candidate in [
    bundled,
    if (root != null) p.join(root, 'bin', command),
  ]) {
    if (File(candidate).existsSync()) return candidate;
  }
  throw RunAborted(
    '$projectRoot depends on the Flutter SDK, but butcher found no flutter '
    "command: run butcher with Flutter's own dart, or set FLUTTER_ROOT.",
  );
}

/// Whether any dependency of the package at [projectRoot] comes from the
/// Flutter SDK, `flutter_test` alone included.
bool _dependsOnFlutter(String projectRoot) {
  final manifest = File(p.join(projectRoot, 'pubspec.yaml'));
  if (!manifest.existsSync()) return false;
  final document = loadYaml(manifest.readAsStringSync());
  if (document is! YamlMap) return false;
  for (final key in ['dependencies', 'dev_dependencies']) {
    final section = document[key];
    if (section is! YamlMap) continue;
    for (final dependency in section.values) {
      if (dependency is YamlMap && dependency['sdk'] == 'flutter') return true;
    }
  }
  return false;
}
