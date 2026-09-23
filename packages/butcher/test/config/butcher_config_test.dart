import 'dart:io';

import 'package:butcher/src/config/butcher_config.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<Directory> projectRoot() async {
  final dir = await Directory.systemTemp.createTemp('butcher_config_');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

void write(Directory dir, String contents) =>
    File(p.join(dir.path, butcherConfigFile)).writeAsStringSync(contents);

void main() {
  test('a missing file excludes nothing', () async {
    final dir = await projectRoot();
    expect(ButcherConfig.load(dir.path).exclude, isEmpty);
  });

  test('an empty file excludes nothing', () async {
    final dir = await projectRoot();
    write(dir, '');
    expect(ButcherConfig.load(dir.path).exclude, isEmpty);
  });

  test('a file without an exclude key excludes nothing', () async {
    final dir = await projectRoot();
    write(dir, 'other: 1\n');
    expect(ButcherConfig.load(dir.path).exclude, isEmpty);
  });

  test('reads a list of glob strings in order', () async {
    final dir = await projectRoot();
    write(dir, 'exclude:\n  - lib/src/generated/**\n  - lib/legacy.dart\n');
    expect(ButcherConfig.load(dir.path).exclude, [
      'lib/src/generated/**',
      'lib/legacy.dart',
    ]);
  });

  test('an empty list excludes nothing', () async {
    final dir = await projectRoot();
    write(dir, 'exclude: []\n');
    expect(ButcherConfig.load(dir.path).exclude, isEmpty);
  });

  test('a malformed exclude value throws naming the key', () async {
    final dir = await projectRoot();
    write(dir, 'exclude: lib/src/**\n');
    expect(
      () => ButcherConfig.load(dir.path),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('exclude'), contains(butcherConfigFile)),
        ),
      ),
    );
  });

  test('a list holding a non-string throws naming the key', () {
    expect(
      () => ButcherConfig.parse('exclude:\n  - 1\n'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('exclude'),
        ),
      ),
    );
  });

  test('a document that is not a map throws naming the file', () {
    expect(
      () => ButcherConfig.parse('- lib/src/**\n'),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(butcherConfigFile),
        ),
      ),
    );
  });
}
