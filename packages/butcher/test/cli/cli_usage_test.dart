import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:butcher/src/cli/cli.dart';
import 'package:test/test.dart';

import '../helpers/paths.dart';

void main() {
  late ButcherPaths paths;

  setUp(() async => paths = await isolatedButcherPaths('rad_cli_usage_'));

  test('rejects a missing coverage report with exit code 64', () async {
    expect(
      await radMain(
        ['--coverage', p.join(paths.root, 'nope.info')],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
  });

  test('rejects an invalid timeout ceiling with exit code 64', () async {
    expect(
      await radMain(
        ['--max-timeouts', '-1'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
    expect(
      await radMain(
        ['--max-timeouts', 'few'],
        out: StringBuffer(),
        paths: paths,
      ),
      64,
    );
  });

  test('rejects an invalid threshold with exit code 64', () async {
    expect(
      await radMain(['--threshold', 'nope'], out: StringBuffer(), paths: paths),
      64,
    );
    expect(
      await radMain(['--threshold', '101'], out: StringBuffer(), paths: paths),
      64,
    );
    expect(
      await radMain(['--threshold', 'NaN'], out: StringBuffer(), paths: paths),
      64,
    );
  });

  test('rejects multiple project roots with exit code 64', () async {
    expect(await radMain(['a', 'b'], out: StringBuffer(), paths: paths), 64);
  });

  test('rejects an invalid job count with exit code 64', () async {
    expect(
      await radMain(['--jobs', '0'], out: StringBuffer(), paths: paths),
      64,
    );
    expect(
      await radMain(['--jobs', 'many'], out: StringBuffer(), paths: paths),
      64,
    );
  });

  test('prints usage with exit code 0 for --help', () async {
    final out = StringBuffer();
    expect(await radMain(['--help'], out: out, paths: paths), 0);
    expect(out.toString(), contains('Usage: rad'));
    expect(out.toString(), contains('BUTCHER_TEMP'));
  });
}
