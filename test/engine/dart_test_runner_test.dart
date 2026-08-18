@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';

import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/capped_output.dart';
import 'package:radioactive_dart/src/engine/outcome_classifier.dart';
import 'package:test/test.dart';

import '../helpers/fixtures.dart';

/// A `dart test --reporter json` stream for [tests] tests, [failing] naming
/// the one that fails.
String reporterEvents({required int tests, required int failing}) {
  final events = StringBuffer();
  for (var id = 0; id < tests; id++) {
    events.writeln(
      jsonEncode({
        'test': {
          'id': id,
          'name': 'engine parses a deeply nested configuration document $id',
          'suiteID': 0,
          'groupIDs': [1, 2],
          'metadata': {'skip': false, 'skipReason': null},
          'line': id,
          'column': 5,
          'url': 'file:///home/runner/project/test/engine/feature_test.dart',
        },
        'type': 'testStart',
        'time': id * 7,
      }),
    );
    events.writeln(
      jsonEncode({
        'testID': id,
        'result': id == failing ? 'failure' : 'success',
        'skipped': false,
        'hidden': false,
        'type': 'testDone',
        'time': id * 7 + 3,
      }),
    );
  }
  return events.toString();
}

Outcome classify(TestRun run) => const OutcomeClassifier().classify(
  run,
  run.events ?? TestEvents.parse(run.output),
);

void main() {
  test('reports a green suite with exit code 0', () async {
    final dir = await createFixturePackage(
      testSource: '''
import 'dart:io';

import 'package:fixture/calc.dart';
import 'package:test/test.dart';

void main() {
  stderr.writeln('noise on stderr');
  test('adds', () => expect(add(2, 3), 5));
}
''',
    );
    final run = await DartTestRunner(dir.path).run();
    expect(run.exitCode, 0);
    expect(run.timedOut, isFalse);
    expect(run.output, contains('"type":"done"'));
    expect(run.events, isNotNull);
    expect(run.output, isNot(contains('noise on stderr')));
    expect(run.errorOutput, contains('noise on stderr'));
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

  test('caps flooding stderr without touching the verdict on stdout', () async {
    final dir = await createFixturePackage(
      testSource: '''
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('floods', () {
    for (var i = 0; i < 2000; i++) {
      stderr.writeln('x' * 200);
    }
    fail('boom');
  });
}
''',
    );

    final run = await DartTestRunner(dir.path).run();

    expect(run.errorOutput.length, lessThan(DartTestRunner.stderrLimit + 64));
    expect(run.errorOutput, contains('[rad] truncated'));
    expect(run.output, isNot(contains('[rad] truncated')));
    expect(classify(run), Outcome.killed);
  });

  test('parses a mid-stream failure before capping its raw evidence', () {
    final buffer = CappedOutput(limit: DartTestRunner.stdoutLimit);
    final events = TestEvents();
    void add(String chunk) {
      events.add(chunk);
      buffer.write(chunk);
    }

    final filler = '${'x' * 8192}\n';
    for (var i = 0; i < 600; i++) {
      add(filler);
    }
    add(reporterEvents(tests: 1, failing: 0));
    for (var i = 0; i < 600; i++) {
      add(filler);
    }
    events.close();
    expect('$buffer', contains('[rad] truncated'));
    expect('$buffer', isNot(contains('"result":"failure"')));
    final run = TestRun(
      exitCode: 1,
      timedOut: false,
      output: '$buffer',
      events: events,
      duration: Duration.zero,
    );
    expect(classify(run), Outcome.killed);
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
    expect(classify(run), Outcome.timeout);
  });

  test('yields an empty process snapshot when the image has no ps', () async {
    // Without a snapshot the tree stays unknown, but the hung suite is still
    // killed and still times out instead of erroring out of the run.
    expect(await DartTestRunner.processSnapshot('rad_absent_ps'), isEmpty);
  });

  test('collects transitive descendants from ps output', () {
    const ps = '''
    1     0
  100     1
  200   100
  201   100
  300   200
  400     1
garbage line
''';
    expect(
      DartTestRunner.descendantPids(ps, 100),
      unorderedEquals([200, 201, 300]),
    );
    expect(DartTestRunner.descendantPids(ps, 999), isEmpty);
  });
}
