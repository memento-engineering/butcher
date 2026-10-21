import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/cli/cli.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

void main() {
  late ButcherPaths paths;

  setUp(() async => paths = await isolatedButcherPaths('butcher_cli_usage_'));

  test('rejects a missing coverage report with exit code 64', () async {
    expect(
      await butcherMain(
        ['--coverage', p.join(paths.root, 'nope.info')],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
  });

  test('rejects an invalid timeout ceiling with exit code 64', () async {
    expect(
      await butcherMain(
        ['--max-timeouts', '-1'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
    expect(
      await butcherMain(
        ['--max-timeouts', 'few'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
  });

  test('rejects an invalid threshold with exit code 64', () async {
    expect(
      await butcherMain(
        ['--threshold', 'nope'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
    expect(
      await butcherMain(
        ['--threshold', '101'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
    expect(
      await butcherMain(
        ['--threshold', 'NaN'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
  });

  test('rejects multiple project roots with exit code 64', () async {
    expect(
      await butcherMain(['a', 'b'], out: StringBuffer(), paths: paths),
      64,
    );
  });

  test('rejects an invalid job count with exit code 64', () async {
    expect(
      await butcherMain(['--jobs', '0'], out: StringBuffer(), paths: paths),
      64,
    );
    expect(
      await butcherMain(['--jobs', 'many'], out: StringBuffer(), paths: paths),
      64,
    );
  });

  test('rejects --files together with --diff-base with exit code 64', () async {
    expect(
      await butcherMain(
        ['--files', 'lib/calc.dart', '--diff-base', 'HEAD'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
  });

  test('rejects --files outside lib or missing with exit code 64', () async {
    final dir = await createFixturePackage(resolve: false);
    for (final file in [
      'test/calc_test.dart',
      'lib/nope.dart',
      'pubspec.yaml',
    ]) {
      expect(
        await butcherMain(
          ['--files', file, dir.path],
          out: StringBuffer(),
          paths: paths,
        ),
        64,
        reason: file,
      );
    }
  });

  test('rejects missing or outside test entries with exit code 64', () async {
    final dir = await createFixturePackage(resolve: false);
    for (final file in [
      'test/nope.dart',
      '../calc_test.dart',
      'pubspec.yaml',
    ]) {
      expect(
        await butcherMain(
          ['--test', file, dir.path],
          out: StringBuffer(),
          paths: paths,
        ),
        64,
        reason: file,
      );
    }
    File(
      p.join(dir.path, 'butcher.yaml'),
    ).writeAsStringSync('tests:\n  - test/nope.dart\n');
    expect(
      await butcherMain([dir.path], out: StringBuffer(), paths: paths),
      64,
    );
  });

  test('rejects an unresolvable --diff-base with exit code 64', () async {
    final dir = await createFixturePackage(resolve: false);
    expect(
      await butcherMain(
        ['--diff-base', 'no-such-ref', dir.path],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
  });

  test('rejects an invalid heap cap with exit code 64', () async {
    for (final value in ['0', 'lots']) {
      expect(
        await butcherMain(
          ['--max-heap-mb', value],
          out: StringBuffer(),
          paths: paths,
        ),
        64,
        reason: value,
      );
    }
  });

  test('prints usage with exit code 0 for --help', () async {
    final out = StringBuffer();
    expect(await butcherMain(['--help'], out: out, paths: paths), 0);
    expect(out.toString(), contains('Usage: butcher'));
    expect(out.toString(), contains('BUTCHER_TEMP'));
  });
}
