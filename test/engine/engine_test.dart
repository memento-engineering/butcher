import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:test/test.dart';

const _killedOutput = '''
{"test":{"id":3,"name":"adds"},"type":"testStart"}
{"testID":3,"result":"failure","skipped":false,"hidden":false,"type":"testDone"}
''';

final class FakeRunner implements TestRunner {
  FakeRunner({this.baselineExitCode = 0});

  final int baselineExitCode;
  final List<Duration?> timeouts = [];

  @override
  Future<TestRun> run({List<String>? tests, Duration? timeout}) async {
    timeouts.add(timeout);
    final baseline = timeouts.length == 1;
    return TestRun(
      exitCode: baseline ? baselineExitCode : 1,
      timedOut: false,
      output: baseline ? '' : _killedOutput,
      duration: const Duration(seconds: 1),
    );
  }
}

final class NothingCovered implements CoverageProvider {
  const NothingCovered();

  @override
  bool isCovered(Mutant mutant) => false;
}

Future<String> miniProject() async {
  final dir = await Directory.systemTemp.createTemp('rad_engine_');
  addTearDown(() => dir.delete(recursive: true));
  File(p.join(dir.path, 'pubspec.yaml'))
      .writeAsStringSync('name: fixture\nenvironment:\n  sdk: ^3.0.0\n');
  File(p.join(dir.path, 'lib', 'calc.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('int add(int a, int b) => a + b;\n');
  return dir.path;
}

void main() {
  test(
    'classifies every mutant with the half-life and reports progress',
    () async {
      final runner = FakeRunner();
      final progress = <String>[];
      final result = await Engine(
        projectRoot: await miniProject(),
        runnerFactory: (_) => runner,
        onProgress: (done, total, mutant, outcome) =>
            progress.add('$done/$total ${outcome.name}'),
      ).run();

      expect(result.results, hasLength(2));
      expect(result.results.map((r) => r.outcome).toSet(), {Outcome.killed});
      expect(result.halfLife, const Duration(seconds: 10));
      expect(progress, ['1/2 killed', '2/2 killed']);
      expect(runner.timeouts, [null, result.halfLife, result.halfLife]);
    },
  );

  test('skips uncovered mutants without running tests', () async {
    final runner = FakeRunner();
    final result = await Engine(
      projectRoot: await miniProject(),
      runnerFactory: (_) => runner,
      coverage: const NothingCovered(),
    ).run();

    expect(result.results.map((r) => r.outcome).toSet(), {Outcome.noCoverage});
    expect(runner.timeouts, hasLength(1), reason: 'only the baseline ran');
  });

  test('aborts on a red background reading', () async {
    final engine = Engine(
      projectRoot: await miniProject(),
      runnerFactory: (_) => FakeRunner(baselineExitCode: 1),
    );
    await expectLater(engine.run(), throwsA(isA<RunAborted>()));
  });
}
