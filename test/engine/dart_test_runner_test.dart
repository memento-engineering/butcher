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
    expect(run.output, contains('"type":"done"'));
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

  test('stops at the first failure with failFast', () async {
    final dir = await createFixturePackage(
      calc: 'int add(int a, int b) => a - b;\n',
      testSource: '''
import 'package:fixture/calc.dart';
import 'package:test/test.dart';

void main() {
  test('adds', () => expect(add(2, 3), 5));
  test('adds again', () => expect(add(4, 5), 9));
}
''',
    );

    final run = await DartTestRunner(
      dir.path,
      concurrency: 1,
    ).run(failFast: true);

    expect(run.exitCode, 1);
    expect(run.output, isNot(contains('adds again')));
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
