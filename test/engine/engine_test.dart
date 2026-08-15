import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:test/test.dart';

const _killedOutput = '''
{"test":{"id":3,"name":"adds"},"type":"testStart"}
{"testID":3,"result":"failure","skipped":false,"hidden":false,"type":"testDone"}
''';

final class FakeRunner implements TestRunner {
  FakeRunner({
    this.baselineExitCode = 0,
    this.mutantExitCode = 1,
    this.mutantOutput = _killedOutput,
    this.delays = const [],
  });

  final int baselineExitCode;
  final int mutantExitCode;
  final String mutantOutput;

  /// Per-call delays after the baseline; missing entries mean no delay.
  final List<Duration> delays;

  final List<Duration?> timeouts = [];

  @override
  Future<TestRun> run({List<String>? tests, Duration? timeout}) async {
    timeouts.add(timeout);
    final baseline = timeouts.length == 1;
    final call = timeouts.length - 2;
    if (!baseline && call < delays.length) {
      await Future<void>.delayed(delays[call]);
    }
    return TestRun(
      exitCode: baseline ? baselineExitCode : mutantExitCode,
      timedOut: false,
      output: baseline ? '' : mutantOutput,
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
        onProgress: (done, total, result) =>
            progress.add('$done/$total ${result.outcome.name}'),
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

  test(
    'gives every worker its own containment, capped by mutant count',
    () async {
      final roots = <String>[];
      final runner = FakeRunner();
      await Engine(
        projectRoot: await miniProject(),
        jobs: 99,
        runnerFactory: (root) {
          roots.add(root);
          return runner;
        },
      ).run();

      expect(roots, hasLength(2), reason: '2 mutants cap 99 jobs at 2 workers');
      expect(roots.toSet(), hasLength(2), reason: 'containments are distinct');
    },
  );

  test('logs engine stages and keeps failed run logs for analysis', () async {
    final temp = await Directory.systemTemp.createTemp('rad_engine_log_');
    addTearDown(() => temp.delete(recursive: true));
    final logPath = p.join(temp.path, 'rad.log');
    final failedDir = p.join(temp.path, 'failed-runs');
    File(p.join(failedDir, 'stale.log'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('from a previous run');

    final runner = FakeRunner(mutantExitCode: 70, mutantOutput: 'venting core');
    await Engine(
      projectRoot: await miniProject(),
      runnerFactory: (_) => runner,
      logger: RadLogger(verbose: false, path: logPath, console: StringBuffer()),
      failedRunLogDir: failedDir,
    ).run();

    final log = File(logPath).readAsStringSync();
    expect(log, contains('"@mt":"found {MutantCount} mutants in {File}"'));
    expect(log, contains('"@mt":"generated {MutantCount} mutants'));
    expect(log, contains('"@mt":"prepared {Workers} containments'));
    expect(log, contains('"@mt":"background reading green'));
    expect(log, contains('"@mt":"classified {MutantId} as {Outcome}'));
    expect(log, contains('"Outcome":"runError"'));
    expect(log, contains('"@mt":"kept failed run log for {MutantId}'));

    final kept = Directory(failedDir).listSync().whereType<File>().toList();
    expect(kept, hasLength(2), reason: 'one log per failed mutant run');
    expect(kept.first.readAsStringSync(), contains('outcome: runError'));
    expect(kept.first.readAsStringSync(), contains('venting core'));
    expect(
      kept.map((f) => p.basename(f.path)),
      isNot(contains('stale.log')),
      reason: 'a new run clears the previous failed-run logs',
    );
  });

  test('keeps no failed run logs when mutants are killed cleanly', () async {
    final temp = await Directory.systemTemp.createTemp('rad_engine_clean_');
    addTearDown(() => temp.delete(recursive: true));
    final failedDir = p.join(temp.path, 'failed-runs');

    final runner = FakeRunner();
    await Engine(
      projectRoot: await miniProject(),
      runnerFactory: (_) => runner,
      failedRunLogDir: failedDir,
    ).run();

    expect(Directory(failedDir).existsSync(), isFalse);
  });

  test('keeps report order deterministic under parallel completion', () async {
    final runner = FakeRunner(
      delays: const [Duration(milliseconds: 120), Duration(milliseconds: 5)],
    );
    final completionOrder = <String>[];
    final result = await Engine(
      projectRoot: await miniProject(),
      jobs: 2,
      runnerFactory: (_) => runner,
      onProgress: (done, total, r) => completionOrder.add(r.mutant.id),
    ).run();

    final reportIds = result.results.map((r) => r.mutant.id).toList();
    expect(reportIds, [
      'lib/calc.dart:27:arithmetic:*',
      'lib/calc.dart:27:arithmetic:-',
    ], reason: 'results follow mutant order, not completion order');
    expect(completionOrder.toSet(), reportIds.toSet());
  });
}
