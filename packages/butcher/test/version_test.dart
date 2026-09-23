import 'dart:io';

import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

/// The `version:` field of this package's own manifest.
///
/// Read with a regular expression rather than a YAML parser on purpose: the
/// manifest must not grow a `yaml` dependency to satisfy its own test.
String _manifestVersion() {
  final manifest = File('pubspec.yaml');
  expect(
    manifest.existsSync(),
    isTrue,
    reason: 'run this suite from the package root, where pubspec.yaml lives',
  );

  final match = RegExp(
    r'''^version:\s*(\S+)\s*$''',
    multiLine: true,
  ).firstMatch(manifest.readAsStringSync());

  expect(match, isNotNull, reason: 'pubspec.yaml declares no version');

  return match!.group(1)!;
}

void main() {
  test('the version constant matches the manifest', () {
    expect(packageVersion, _manifestVersion());
  });
}
