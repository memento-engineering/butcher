import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../log/rad_logger.dart';
import '../model/mutant.dart';
import '../model/mutant_result.dart';
import '../model/outcome.dart';
import '../mutagens/mutagen_registry.dart';
import '../temp.dart';
import 'containment.dart';
import 'coverage_provider.dart';
import 'dart_test_runner.dart';
import 'full_coverage_provider.dart';
import 'mutant_generator.dart';
import 'outcome_classifier.dart';
import 'run_aborted.dart';
import 'run_result.dart';
import 'test_events.dart';
import 'test_runner.dart';
import 'test_selector.dart';
import 'whole_suite_selector.dart';

/// Called after each classified mutant with progress counters.
typedef ProgressCallback = void Function(
  int done,
  int total,
  MutantResult result,
);

/// Builds a runner rooted at a containment; [suiteConcurrency] is this
/// worker's share of the cores (ADR 0017).
typedef RunnerFactory = TestRunner Function(String root, int suiteConcurrency);

/// Orchestrates a full run: generate, contain, verify, irradiate, classify.
final class Engine {
  /// Creates an engine for the project at [projectRoot].
  Engine({
    required this.projectRoot,
    MutagenRegistry? registry,
    this.coverage = const FullCoverageProvider(),
    this.selector = const WholeSuiteSelector(),
    this.runnerFactory = _defaultRunnerFactory,
    this.onProgress,
    this.logger,
    int? jobs,
    String? runLogDir,
  }) : registry = registry ?? MutagenRegistry.defaults(),
       jobs = jobs ?? defaultJobs,
       runLogDir = runLogDir ?? radRunsPath();

  static TestRunner _defaultRunnerFactory(String root, int suiteConcurrency) =>
      DartTestRunner(root, concurrency: suiteConcurrency);

  /// Default worker count: half the cores, since each suite process
  /// parallelizes internally already (ADR 0017).
  static int get defaultJobs => max(1, Platform.numberOfProcessors ~/ 2);

  /// Absolute or relative path of the project under test.
  final String projectRoot;

  /// The active mutagen set.
  final MutagenRegistry registry;

  /// Coverage seam; MVP default covers everything.
  final CoverageProvider coverage;

  /// Test selection seam; MVP default runs the whole suite.
  final TestSelector selector;

  /// Builds the runner for a containment root; seam for `flutter test`.
  final RunnerFactory runnerFactory;

  /// Optional per-mutant progress hook, called in completion order.
  final ProgressCallback? onProgress;

  /// Number of parallel workers, each owning a containment (ADR 0017).
  final int jobs;

  /// Receives engine wide events; `null` disables engine logging.
  final RadLogger? logger;

  /// Where suite logs of mutant runs are kept (ADR 0016).
  final String runLogDir;

  /// Outcomes recorded as errors in their run log.
  static const failedOutcomes = {
    Outcome.timeout,
    Outcome.unviable,
    Outcome.runError,
    Outcome.memoryError,
  };

  /// Runs the whole pipeline and returns every classified result.
  Future<RunResult> run() async {
    final runsDir = Directory(runLogDir)..createSync(recursive: true);
    for (final entry in runsDir.listSync()) {
      entry.deleteSync(recursive: true);
    }

    final generationWatch = Stopwatch()..start();
    final (mutants, sources) = await MutantGenerator(
      projectRoot: projectRoot,
      registry: registry,
    ).generate();
    final perFile = <String, int>{for (final file in sources.keys) file: 0};
    for (final mutant in mutants) {
      perFile.update(mutant.mutation.filePath, (count) => count + 1);
    }
    perFile.forEach(
      (file, count) => logger?.info('found {MutantCount} mutants in {File}', {
        'MutantCount': count,
        'File': file,
      }),
    );
    logger?.info(
      'generated {MutantCount} mutants in {FileCount} files in {DurationMs} ms',
      {
        'MutantCount': mutants.length,
        'FileCount': sources.length,
        'DurationMs': generationWatch.elapsedMilliseconds,
      },
    );

    final prepareWatch = Stopwatch()..start();
    final workers = max(1, min(jobs, mutants.length));
    final containments = await Future.wait([
      for (var i = 0; i < workers; i++) Containment.create(projectRoot),
    ]);
    try {
      await Future.wait(containments.map((c) => _resolveDependencies(c.root)));
      // Divide the cores among workers so parallel suites do not
      // oversubscribe; the background reading uses the same concurrency to
      // keep half-lives calibrated (ADR 0017).
      final suiteConcurrency = max(1, Platform.numberOfProcessors ~/ workers);
      final runners = [
        for (final c in containments) runnerFactory(c.root, suiteConcurrency),
      ];
      logger?.info(
        'prepared {Workers} containments in {DurationMs} ms, '
        '{SuiteConcurrency} test threads each',
        {
          'Workers': workers,
          'SuiteConcurrency': suiteConcurrency,
          'DurationMs': prepareWatch.elapsedMilliseconds,
        },
      );

      final background = await runners.first.run();
      if (background.exitCode != 0) {
        final summary = TestEvents.parse(background.output).summarize();
        throw RunAborted(
          'background reading is red; a green suite is a precondition '
          '(ADR 0005). If a copy exclusion removed a required asset, fix '
          '$containmentIgnoreFile.\n'
          '${summary.isEmpty ? background.output : summary}',
        );
      }
      final halfLife = halfLifeFor(background.duration);
      logger?.info(
        'background reading green in {DurationMs} ms, '
        'half-life {HalfLifeMs} ms',
        {
          'DurationMs': background.duration.inMilliseconds,
          'HalfLifeMs': halfLife.inMilliseconds,
        },
      );

      // One shared queue; results keyed by index so completion order never
      // changes the report (ADR 0007, ADR 0017).
      final results = List<MutantResult?>.filled(mutants.length, null);
      var next = 0;
      var done = 0;
      Future<void> worker(int slot) async {
        while (true) {
          final index = next++;
          if (index >= mutants.length) return;
          final result = await _classify(
            mutants[index],
            containments[slot],
            runners[slot],
            halfLife,
          );
          results[index] = result;
          done++;
          logger?.info('classified {MutantId} as {Outcome} ({Done}/{Total})', {
            'MutantId': result.mutant.id,
            'Outcome': result.outcome.name,
            'Done': done,
            'Total': mutants.length,
            'Worker': slot,
            'ExitCode': result.testRun?.exitCode,
            'TimedOut': result.testRun?.timedOut,
            'DurationMs': result.testRun?.duration.inMilliseconds,
          });
          if (result.testRun != null) {
            final logFile = _keepRunLog(result);
            logger?.info('kept run log for {MutantId} at {Path}', {
              'MutantId': result.mutant.id,
              'Path': logFile,
            });
          }
          onProgress?.call(done, mutants.length, result);
        }
      }

      await Future.wait([for (var i = 0; i < workers; i++) worker(i)]);
      return RunResult(
        results: results.cast<MutantResult>(),
        sources: sources,
        backgroundReading: background.duration,
        halfLife: halfLife,
      );
    } finally {
      await Future.wait(containments.map((c) => c.dispose()));
    }
  }

  Future<MutantResult> _classify(
    Mutant mutant,
    Containment containment,
    TestRunner runner,
    Duration halfLife,
  ) async {
    if (!coverage.isCovered(mutant)) {
      return MutantResult(mutant: mutant, outcome: Outcome.noCoverage);
    }
    try {
      await containment.apply(mutant.mutation);
      final run = await runner.run(
        tests: selector.select(mutant),
        timeout: halfLife,
      );
      return MutantResult(
        mutant: mutant,
        outcome: const OutcomeClassifier().classify(run),
        testRun: run,
      );
    } catch (_) {
      // Mutant-level failures are outcomes, never exceptions (ADR 0006).
      return MutantResult(mutant: mutant, outcome: Outcome.runError);
    } finally {
      await containment.restore(mutant.mutation.filePath);
    }
  }

  /// Writes a CLEF log for one mutant run, correlated with the tool log
  /// through the shared `RunId` (ADR 0016).
  String _keepRunLog(MutantResult result) {
    final run = result.testRun!;
    final mutation = result.mutant.mutation;
    final directory = Directory(runLogDir)..createSync(recursive: true);
    final name = result.mutant.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(p.join(directory.path, '$name.log'));
    final runLogger = RadLogger(
      verbose: false,
      path: file.path,
      runId: logger?.runId,
    );
    final properties = {
      'MutantId': result.mutant.id,
      'Outcome': result.outcome.name,
      'Mutation': mutation.description,
      'File': mutation.filePath,
      'Offset': mutation.offset,
      'Operator': mutation.operatorId,
      'Replacement': mutation.replacement,
      'ExitCode': run.exitCode,
      'TimedOut': run.timedOut,
      'DurationMs': run.duration.inMilliseconds,
      'Output': run.output,
    };
    if (failedOutcomes.contains(result.outcome)) {
      runLogger.error('mutant run failed: {MutantId} as {Outcome}', properties);
    } else {
      runLogger.info(
        'mutant run completed: {MutantId} as {Outcome}',
        properties,
      );
    }
    for (final error in TestEvents.parse(run.output).errors) {
      runLogger.error('nested test error: {Error}', {'Error': error});
    }
    return file.path;
  }

  /// Per-mutant timeout: `max(background × 3, 10 s floor)` (ADR 0006).
  static Duration halfLifeFor(Duration background) {
    const floor = Duration(seconds: 10);
    final scaled = background * 3;
    return Duration(
      microseconds: max(scaled.inMicroseconds, floor.inMicroseconds),
    );
  }

  Future<void> _resolveDependencies(String root) async {
    final pubGet = await Process.run(Platform.resolvedExecutable, [
      'pub',
      'get',
    ], workingDirectory: root);
    if (pubGet.exitCode != 0) {
      throw RunAborted(
        'pub get failed in the containment:\n'
        '${pubGet.stdout}${pubGet.stderr}',
      );
    }
  }
}
