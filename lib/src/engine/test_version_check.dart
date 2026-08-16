import 'dart:io';

import 'package:path/path.dart' as p;

import 'run_aborted.dart';

/// Oldest `package:test` whose CLI supports `--fail-fast`, which every
/// mutant run passes.
const minTestVersion = '1.24.6';

/// Aborts when the resolved `package:test` in [projectRoot] predates
/// [minTestVersion]; a missing lockfile or `test` entry passes.
void ensureTestVersion(String projectRoot) {
  final lock = File(p.join(projectRoot, 'pubspec.lock'));
  if (!lock.existsSync()) return;
  final version = RegExp(
    r'^  test:.*?^    version: "([^"]+)"',
    multiLine: true,
    dotAll: true,
  ).firstMatch(lock.readAsStringSync())?.group(1);
  if (version == null || !_isOlder(version, minTestVersion)) return;
  throw RunAborted(
    'resolved package:test $version does not support --fail-fast; '
    'rad needs test $minTestVersion or newer.',
  );
}

bool _isOlder(String version, String minimum) {
  final left = _numbers(version);
  if (left == null) return false;
  final right = _numbers(minimum)!;
  for (var i = 0; i < right.length; i++) {
    final part = i < left.length ? left[i] : 0;
    if (part != right[i]) return part < right[i];
  }
  return false;
}

List<int>? _numbers(String version) {
  final parts = version.split('+').first.split('-').first.split('.');
  final numbers = [for (final part in parts) int.tryParse(part)];
  return numbers.contains(null) ? null : numbers.cast<int>();
}
