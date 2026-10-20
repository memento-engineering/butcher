@Timeout(Duration(minutes: 5))
@Tags(['slow', 'flutter'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:butcher/butcher.dart';
import 'package:butcher/src/cli/cli.dart';
import 'package:butcher/src/engine/flutter_sdk.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/fixtures.dart';
import '../helpers/paths.dart';

const _pubspec = '''
name: flutter_fixture
environment:
  sdk: ^3.0.0
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
''';

const _calc = '''
import 'package:flutter/widgets.dart';

int add(int a, int b) => a + b;

class Sum extends StatelessWidget {
  const Sum({super.key});

  @override
  Widget build(BuildContext context) =>
      Text('\${add(2, 3)}', textDirection: TextDirection.ltr);
}
''';

const _test = '''
import 'package:flutter_fixture/calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the sum', (tester) async {
    await tester.pumpWidget(const Sum());
    expect(find.text('5'), findsOneWidget);
  });
}
''';

Future<Directory> _flutterFixture() async {
  final dir = await Directory.systemTemp.createTemp('butcher_flutter_');
  addTearDown(() => dir.delete(recursive: true));
  for (final (path, content) in [
    ('pubspec.yaml', _pubspec),
    ('lib/calc.dart', _calc),
    ('test/calc_test.dart', _test),
  ]) {
    File(p.join(dir.path, path))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }
  await initGitRepository(dir.path);
  return dir;
}

/// Why the suite cannot run here, or `null` when a Flutter SDK is reachable
/// the way butcher itself would reach it.
String? _noFlutter() {
  final probe = Directory.systemTemp.createTempSync('butcher_flutter_probe_');
  try {
    File(p.join(probe.path, 'pubspec.yaml')).writeAsStringSync(_pubspec);
    flutterFor(probe.path);
    return null;
  } on RunAborted {
    return 'no Flutter SDK beside this dart or under FLUTTER_ROOT';
  } finally {
    probe.deleteSync(recursive: true);
  }
}

void main() {
  late ButcherPaths paths;

  setUp(() async => paths = await isolatedButcherPaths('butcher_flutter_'));

  group('a Flutter package', skip: _noFlutter(), () {
    test('gets a green baseline and a Stryker report', () async {
      final dir = await _flutterFixture();
      final out = StringBuffer();

      final exit = await butcherMain(
        ['--jobs', '2', '--output', 'report.json', dir.path],
        out: out,
        paths: paths,
      );

      expect(exit, 0, reason: out.toString());
      expect(out.toString(), contains('MSI: 100.00%'));
      final report =
          jsonDecode(File(p.join(dir.path, 'report.json')).readAsStringSync())
              as Map<String, dynamic>;
      expect((report['files'] as Map<String, dynamic>).keys, ['lib/calc.dart']);
    });

    test('rejects --max-heap-mb with exit code 64', () async {
      final dir = await _flutterFixture();

      expect(
        await butcherMain(
          ['--max-heap-mb', '512', dir.path],
          out: StringBuffer(),
          paths: paths,
        ),
        64,
      );
    });
  });
}
