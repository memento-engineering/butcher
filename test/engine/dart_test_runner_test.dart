@Timeout(Duration(minutes: 2))
library;

import 'package:radioactive_dart/src/engine/dart_test_runner.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

void main() {
  test('reports a green suite with exit code 0', () async {
    final dir = await createFixturePackage();
    final run = await DartTestRunner(dir.path).run();
    expect(run.exitCode, 0);
    expect(run.timedOut, isFalse);
    expect(run.output, contains('All tests passed!'));
    expect(run.duration, greaterThan(Duration.zero));
  });

  test('reports a failing suite with exit code 1', () async {
    final dir = await createFixturePackage(
      calc: 'int add(int a, int b) => a - b;\n',
    );
    final run = await DartTestRunner(dir.path).run();
    expect(run.exitCode, 1);
    expect(run.timedOut, isFalse);
  });

  test('kills a hung suite at its half-life', () async {
    final dir = await createFixturePackage(
      testSource: '''
import 'package:test/test.dart';

void main() {
  test('hangs', () { while (true) {} });
}
''',
    );
    final run = await DartTestRunner(dir.path)
        .run(timeout: const Duration(seconds: 10));
    expect(run.timedOut, isTrue);
    expect(run.exitCode, -1);
  });
}
