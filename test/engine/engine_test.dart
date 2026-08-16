import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:radioactive_dart/radioactive_dart.dart';
import 'package:test/test.dart';

import '../helpers/paths.dart';

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

  /// One entry per call: whether it asked the suite to stop at first failure.
  final List<bool> failFasts = [];

  @override
  Future<TestRun> run({
    List<String>? tests,
    Duration? timeout,
    bool failFast = false,
  }) async {
    timeouts.add(timeout);
    failFasts.add(failFast);
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

Future<String> miniProject({
  String calc = 'int add(int a, int b) => a + b;\n',
}) async {
  final dir = await Directory.systemTemp.createTemp('rad_engine_');
  addTearDown(() => dir.delete(recursive: true));
  File(p.join(dir.path, 'pubspec.yaml'))
      .writeAsStringSync('name: fixture\nenvironment:\n  sdk: ^3.0.0\n');
  File(p.join(dir.path, 'lib', 'calc.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(calc);
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
        paths: await isolatedRadPaths('rad_engine_state_'),
        runnerFactory: (_, _) => runner,
        onProgress: (done, total, result) =>
            progress.add('$done/$total ${result.outcome.name}'),
      ).run();

      expect(result.results, hasLength(2));
      expect(result.results.map((r) => r.outcome).toSet(), {Outcome.killed});
      expect(result.halfLife, const Duration(seconds: 10));
      expect(progress, ['1/2 killed', '2/2 killed']);
      expect(runner.timeouts, [null, result.halfLife, result.halfLife]);
      expect(runner.failFasts, [
        false,
        true,
        true,
      ], reason: 'mutant runs stop at the first failure, the reading does not');
    },
  );

  test('skips uncovered mutants without running tests', () async {
    final root = await miniProject();
    final paths = await isolatedRadPaths('rad_engine_state_');
    final runner = FakeRunner();
    final result = await Engine(
      projectRoot: root,
      paths: paths,
      runnerFactory: (_, _) => runner,
      coverage: const NothingCovered(),
    ).run();

    expect(result.results.map((r) => r.outcome).toSet(), {Outcome.noCoverage});
    expect(runner.timeouts, hasLength(1), reason: 'only the baseline ran');
    expect(Directory(paths.runLogs).existsSync(), isTrue);
    expect(Directory(paths.runLogs).listSync(), isEmpty);
  });

  test('classifies non-compiling mutants without running tests', () async {
    final root = await miniProject(
      calc:
          'String? tag(String? raw) {\n'
          '  if (raw == null) return null;\n'
          '  return raw.trim();\n'
          '}\n',
    );
    final runner = FakeRunner();
    final result = await Engine(
      projectRoot: root,
      paths: await isolatedRadPaths('rad_engine_state_'),
      runnerFactory: (_, _) => runner,
    ).run();

    expect(result.results.map((r) => r.outcome).toSet(), {Outcome.unviable});
    expect(runner.timeouts, hasLength(1), reason: 'only the baseline ran');
  });

  test('aborts on a red background reading', () async {
    final engine = Engine(
      projectRoot: await miniProject(),
      paths: await isolatedRadPaths('rad_engine_state_'),
      runnerFactory: (_, _) => FakeRunner(baselineExitCode: 1),
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
        paths: await isolatedRadPaths('rad_engine_state_'),
        jobs: 99,
        runnerFactory: (root, _) {
          roots.add(root);
          return runner;
        },
      ).run();

      expect(roots, hasLength(2), reason: '2 mutants cap 99 jobs at 2 workers');
      expect(roots.toSet(), hasLength(2), reason: 'containments are distinct');
    },
  );

  test('logs engine stages without removing existing run logs', () async {
    final temp = await Directory.systemTemp.createTemp('rad_engine_log_');
    addTearDown(() => temp.delete(recursive: true));
    final paths = RadPaths(root: temp.path);
    File(p.join(paths.runLogs, 'stale.log'))
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('from a previous run');

    final runner = FakeRunner(mutantExitCode: 70, mutantOutput: 'venting core');
    final toolLogger = RadLogger(
      verbose: false,
      path: paths.toolLog,
      console: StringBuffer(),
    );
    await Engine(
      projectRoot: await miniProject(),
      paths: paths,
      jobs: 2,
      runnerFactory: (_, _) => runner,
      logger: toolLogger,
    ).run();

    final log = File(paths.toolLog).readAsStringSync();
    expect(log, contains('"@mt":"found {MutantCount} mutants in {File}"'));
    expect(log, contains('"@mt":"generated {MutantCount} mutants'));
    expect(log, contains('"@mt":"checked viability of {MutantCount} mutants'));
    expect(log, contains('"@mt":"prepared {Workers} containments'));
    expect(log, contains('"@mt":"background reading green'));
    expect(log, contains('"@mt":"classified {MutantId} as {Outcome}'));
    expect(log, contains('"Outcome":"runError"'));
    expect(
      log,
      contains('"Containment":"containment_'),
      reason: 'the tool log points at the run log that holds the detail',
    );

    final newLogs = Directory(paths.runLogs)
        .listSync()
        .whereType<File>()
        .where((file) => p.basename(file.path) != 'stale.log')
        .toList();
    expect(
      newLogs.map((file) => p.basename(file.path)),
      everyElement(startsWith('containment_')),
      reason: 'one run log per containment, named after it',
    );
    final events = [
      for (final file in newLogs)
        for (final line in file.readAsLinesSync())
          jsonDecode(line) as Map<String, dynamic>,
    ];
    expect(events, hasLength(2), reason: 'one event per executed mutant');
    for (final event in events) {
      expect(event['@mt'], 'mutant run failed: {MutantId} as {Outcome}');
      expect(event['@l'], 'Error');
      expect(event['Outcome'], 'runError');
      expect(event['Output'], contains('venting core'));
      expect(event['Containment'], startsWith('containment_'));
      expect(
        event['RunId'],
        toolLogger.runId,
        reason: 'run logs correlate with the tool log',
      );
    }
    expect(
      File(p.join(paths.runLogs, 'stale.log')).existsSync(),
      isTrue,
      reason: 'nested engine runs must not clear another run\'s logs',
    );

    final firstRunPaths = newLogs.map((file) => file.path).toList();
    await Engine(
      projectRoot: await miniProject(),
      paths: paths,
      jobs: 2,
      runnerFactory: (_, _) => FakeRunner(),
    ).run();
    expect(
      firstRunPaths.every((path) => File(path).existsSync()),
      isTrue,
      reason: 'a later successful engine run keeps abnormal-run logs',
    );
  });

  test('keeps run logs when mutants are killed cleanly', () async {
    final temp = await Directory.systemTemp.createTemp('rad_engine_clean_');
    addTearDown(() => temp.delete(recursive: true));
    final paths = RadPaths(root: temp.path);

    final runner = FakeRunner();
    await Engine(
      projectRoot: await miniProject(),
      paths: paths,
      runnerFactory: (_, _) => runner,
    ).run();

    final kept = Directory(paths.runLogs).listSync().whereType<File>().toList();
    expect(kept, isNotEmpty);
    final events = [
      for (final file in kept)
        for (final line in file.readAsLinesSync())
          jsonDecode(line) as Map<String, dynamic>,
    ];
    expect(events, hasLength(2));
    for (final event in events) {
      expect(event['@mt'], 'mutant run completed: {MutantId} as {Outcome}');
      expect(event, isNot(contains('@l')));
      expect(event['Outcome'], 'killed');
      expect(event['Output'], contains('"result":"failure"'));
    }
  });

  test('divides the suite concurrency among workers', () async {
    final concurrencies = <int>[];
    final runner = FakeRunner();
    await Engine(
      projectRoot: await miniProject(),
      paths: await isolatedRadPaths('rad_engine_state_'),
      jobs: 2,
      runnerFactory: (_, suiteConcurrency) {
        concurrencies.add(suiteConcurrency);
        return runner;
      },
    ).run();

    final expected = max(1, Platform.numberOfProcessors ~/ 2);
    expect(concurrencies, [expected, expected]);
  });

  test('keeps report order deterministic under parallel completion', () async {
    final runner = FakeRunner(
      delays: const [Duration(milliseconds: 120), Duration(milliseconds: 5)],
    );
    final completionOrder = <String>[];
    final result = await Engine(
      projectRoot: await miniProject(),
      paths: await isolatedRadPaths('rad_engine_state_'),
      jobs: 2,
      runnerFactory: (_, _) => runner,
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
