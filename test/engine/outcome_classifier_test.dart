import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:radioactive_dart/src/engine/outcome_classifier.dart';
import 'package:test/test.dart';

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

  test('classifies a failing suite as killed', () {
    expect(
      classifier.classify(run(exitCode: 1, output: 'Some tests failed.')),
      Outcome.killed,
    );
  });

  test('classifies a load failure as unviable', () {
    expect(
      classifier.classify(
        run(exitCode: 1, output: 'Failed to load "test/calc_test.dart"'),
      ),
      Outcome.unviable,
    );
  });

  test('classifies a killed process as timeout', () {
    expect(
      classifier.classify(run(exitCode: -1, timedOut: true)),
      Outcome.timeout,
    );
  });

  test('classifies unexpected exit codes as runError', () {
    expect(classifier.classify(run(exitCode: 70)), Outcome.runError);
    expect(classifier.classify(run(exitCode: -1073741819)), Outcome.runError);
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
