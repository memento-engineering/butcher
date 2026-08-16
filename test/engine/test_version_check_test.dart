import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/src/engine/run_aborted.dart';
import 'package:radioactive_dart/src/engine/test_version_check.dart';
import 'package:test/test.dart';

String _lock(Map<String, String> packages) =>
    'packages:\n${packages.entries.map((entry) => '''
  ${entry.key}:
    dependency: "direct dev"
    source: hosted
    version: "${entry.value}"
''').join()}sdks:\n  dart: ">=3.0.0"\n';

Future<String> _project({String? lock}) async {
  final dir = await Directory.systemTemp.createTemp('rad_test_version_');
  addTearDown(() => dir.delete(recursive: true));
  if (lock != null) {
    File(p.join(dir.path, 'pubspec.lock')).writeAsStringSync(lock);
  }
  return dir.path;
}

void main() {
  test('aborts on a test version older than $minTestVersion', () async {
    final root = await _project(lock: _lock({'test': '1.24.5'}));
    expect(
      () => ensureTestVersion(root),
      throwsA(
        isA<RunAborted>().having(
          (abort) => abort.message,
          'message',
          allOf(contains('1.24.5'), contains(minTestVersion)),
        ),
      ),
    );
  });

  test('passes the minimum version and newer ones', () async {
    ensureTestVersion(await _project(lock: _lock({'test': minTestVersion})));
    ensureTestVersion(await _project(lock: _lock({'test': '1.26.3'})));
    ensureTestVersion(await _project(lock: _lock({'test': '2.0.0'})));
  });

  test('passes without a lockfile or test entry', () async {
    ensureTestVersion(await _project());
    ensureTestVersion(await _project(lock: _lock({'test_api': '0.7.0'})));
  });

  test('reads the test entry, not an earlier package', () async {
    final root = await _project(
      lock: _lock({'analyzer': '1.0.0', 'test': '1.24.0', 'yaml': '9.9.9'}),
    );
    expect(() => ensureTestVersion(root), throwsA(isA<RunAborted>()));
  });
}
