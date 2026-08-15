import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/outcome_classifier.dart';
import 'package:radioactive_dart/src/engine/test_events.dart';
import 'package:test/test.dart';

const _failedTest = '''
{"test":{"id":3,"name":"adds"},"type":"testStart"}
{"testID":3,"error":"Expected: <5>\\n  Actual: <-1>","type":"error"}
{"testID":3,"result":"failure","skipped":false,"hidden":false,"type":"testDone"}
''';

const _loadFailure = '''
{"test":{"id":1,"name":"loading test/calc_test.dart"},"type":"testStart"}
{"testID":1,"error":"Failed to load \\"test/calc_test.dart\\":\\nError: ...","type":"error"}
{"testID":1,"result":"error","skipped":false,"hidden":false,"type":"testDone"}
''';

/// A green run whose test prints nested `dart test` text (meta-circular).
const _pollutedFailure = '''
{"test":{"id":1,"name":"loading test/cli_e2e_test.dart"},"type":"testStart"}
{"testID":1,"result":"success","skipped":false,"hidden":true,"type":"testDone"}
{"test":{"id":4,"name":"aborts on red baseline"},"type":"testStart"}
{"testID":4,"message":"Failed to load \\"test/calc_test.dart\\": nested!","type":"print"}
{"testID":4,"result":"failure","skipped":false,"hidden":false,"type":"testDone"}
''';

TestRun run({int exitCode = 0, bool timedOut = false, String output = ''}) =>
    TestRun(
      exitCode: exitCode,
      timedOut: timedOut,
      output: output,
      duration: const Duration(seconds: 1),
    );

void main() {
  const classifier = OutcomeClassifier();

  test('classifies a passing suite as survived', () {
    expect(classifier.classify(run(exitCode: 0)), Outcome.survived);
  });

  test('classifies a failing test as killed', () {
    expect(
      classifier.classify(run(exitCode: 1, output: _failedTest)),
      Outcome.killed,
    );
  });

  test('classifies a load failure as unviable', () {
    expect(
      classifier.classify(run(exitCode: 1, output: _loadFailure)),
      Outcome.unviable,
    );
  });

  test('is not fooled by nested load-failure text in print events', () {
    expect(
      classifier.classify(run(exitCode: 1, output: _pollutedFailure)),
      Outcome.killed,
    );
  });

  test('classifies a killed process as timeout', () {
    expect(
      classifier.classify(run(exitCode: -1, timedOut: true)),
      Outcome.timeout,
    );
  });

  test('classifies unparseable failures as runError', () {
    expect(
      classifier.classify(run(exitCode: 70, output: 'venting core')),
      Outcome.runError,
    );
    expect(classifier.classify(run(exitCode: 1)), Outcome.runError);
  });

  group('TestEvents', () {
    test('summarizes errors with their test names', () {
      final events = TestEvents.parse(_failedTest);
      expect(events.testFailures, ['adds']);
      expect(events.summarize(), contains('adds: Expected: <5>'));
    });

    test('ignores non-JSON lines', () {
      final events = TestEvents.parse('not json\n$_loadFailure\n42\n');
      expect(events.loadFailures, ['loading test/calc_test.dart']);
      expect(events.testFailures, isEmpty);
    });
  });

  group('half-life', () {
    test('is three background readings when above the floor', () {
      expect(
        Engine.halfLifeFor(const Duration(seconds: 20)),
        const Duration(minutes: 1),
      );
    });

    test('never drops below the 10 s floor', () {
      expect(
        Engine.halfLifeFor(const Duration(milliseconds: 200)),
        const Duration(seconds: 10),
      );
      expect(Engine.halfLifeFor(Duration.zero), const Duration(seconds: 10));
    });
  });
}
