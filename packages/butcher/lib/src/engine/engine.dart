import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../config/mutation_scope.dart';
import '../log/butcher_logger.dart';
import '../model/mutant.dart';
import '../model/mutant_result.dart';
import '../model/outcome.dart';
import '../model/test_events.dart';
import '../model/test_run.dart';
import '../model/test_suite.dart';
import '../mutators/mutator_registry.dart';
import '../butcher_paths.dart';
import 'sandbox.dart';
import 'coverage_collector.dart';
import 'coverage_provider.dart';
import 'dart_test_runner.dart';
import 'full_coverage_provider.dart';
import 'mutant_generator.dart';
import 'outcome_classifier.dart';
import 'pub_get.dart';
import 'pub_workspace.dart';
import 'run_aborted.dart';
import 'run_events.dart';
import 'run_result.dart';
import 'test_runner.dart';
import 'test_version_check.dart';
import 'viability_checker.dart';

/// Called after each classified mutant with progress counters.
typedef ProgressCallback =
    void Function(int done, int total, MutantResult result);

/// Builds a runner rooted at a sandbox; [suiteConcurrency] is this
/// worker's share of the cores (ADR 0017).
typedef RunnerFactory = TestRunner Function(String root, int suiteConcurrency);

/// Orchestrates a full run: sandbox, verify, generate, mutate, classify.
final class Engine {
  /// Creates an engine for the project at [projectRoot].
  Engine({
    required this.projectRoot,
    required this.paths,
    MutatorRegistry? registry,
    this.coverage = const FullCoverageProvider(),
    this.runnerFactory = _defaultRunnerFactory,
    this.onProgress,
    this.logger,
    int? jobs,
  }) : registry = registry ?? MutatorRegistry.defaults(),
       jobs = jobs ?? defaultJobs,
       runId =
           logger?.runId ??
           DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  static TestRunner _defaultRunnerFactory(String root, int suiteConcurrency) =>
      DartTestRunner(root, concurrency: suiteConcurrency);

  /// Default worker count: half the cores, since each suite process
  /// parallelizes internally already (ADR 0017).
  static int get defaultJobs => max(1, Platform.numberOfProcessors ~/ 2);

  /// Absolute or relative path of the project under test.
  final String projectRoot;

  /// Filesystem locations resolved by the caller for this invocation.
  final ButcherPaths paths;

  /// The active mutator set.
  final MutatorRegistry registry;

  /// Coverage seam; `null` collects coverage during the run (ADR 0020).
  final CoverageProvider? coverage;

  /// Builds the runner for a sandbox root; seam for `flutter test`.
  final RunnerFactory runnerFactory;

  /// Optional per-mutant progress hook, called in completion order.
  final ProgressCallback? onProgress;

  /// Number of parallel workers, each owning a sandbox (ADR 0017).
  final int jobs;

  /// Receives engine wide events; `null` disables engine logging.
  final ButcherLogger? logger;

  /// Correlates and namespaces every mutant-run log from this engine run.
  final String runId;

  /// Created with the engine rather than inside [run], so a consumer can
  /// subscribe first and still receive the opening event. Asynchronous on
  /// purpose: a synchronous controller would let a listener reenter the
  /// worker loop.
  final StreamController<RunEvent> _events =
      StreamController<RunEvent>.broadcast();

  /// Live progress of [run], beside the end-of-run [RunResult].
  ///
  /// Subscribe before calling [run]: the stream carries one [RunStarted], one
  /// [MutantClassified] per mutant, and one [RunCompleted], and [run] closes
  /// it in a `finally`, so an aborted run closes the stream instead of leaving
  /// a listener hanging. That makes an engine instance single-use for its
  /// stream: once [run] has finished or thrown, the stream stays closed.
  ///
  /// Event order is NON-DETERMINISTIC: the workers classify in parallel and
  /// publish as they finish. The [RunResult] returned by [run] keeps the
  /// slot-indexed order and is the stable view of the run.
  ///
  /// Delivery is asynchronous, so a listener that throws does not throw inside
  /// the engine: its exception surfaces later in the zone where it subscribed
  /// and never reaches [run], which neither swallows nor observes it.
  Stream<RunEvent> get events => _events.stream;

  /// Publishes [event] unless the run has already closed the controller.
  void _emit(RunEvent event) {
    if (_events.isClosed) return;
    _events.add(event);
  }

  /// Characters of each suite stream kept per mutant. The live stream stays
  /// generous so nothing is parsed truncated, but every mutant's excerpt is
  /// retained until the run ends (ADR 0016).
  static const outputExcerptLimit = 32 * 1024;

  /// Directory inside the baseline sandbox holding the collected VM
  /// coverage reports (ADR 0020).
  static const coverageDirName = '.butcher_coverage';

  /// Outcomes recorded as errors in their run log.
  static const failedOutcomes = {
    Outcome.timeout,
    Outcome.unviable,
    Outcome.runError,
    Outcome.memoryError,
  };

  /// Runs the whole pipeline and returns every classified result.
  ///
  /// Publishes progress on [events] as it goes and closes that stream before
  /// returning or throwing.
  Future<RunResult> run() async {
    try {
      return await _run();
    } finally {
      await _events.close();
    }
  }

  Future<RunResult> _run() async {
    Directory(paths.runLogs).createSync(recursive: true);
    await _provision();
    final workspace = PubWorkspace.resolve(projectRoot);

    // Sandbox and verify before the expensive analysis stages so a red
    // suite aborts within the baseline's duration (ADR 0005).
    final prepareWatch = Stopwatch()..start();
    // Divide the cores among the requested jobs so parallel suites do not
    // oversubscribe; the baseline uses the same concurrency to
    // keep deadlines calibrated (ADR 0017).
    final suiteConcurrency = max(1, Platform.numberOfProcessors ~/ jobs);
    final baseline = await Sandbox.create(
      projectRoot,
      paths: paths,
      workspaceRoot: workspace.root,
      logger: logger,
    );
    await pubGet(baseline.projectRoot, label: 'the sandbox');
    ensureTestVersion(baseline.root);
    // One pristine clone before the baseline; the workers are cloned
    // from it, so none inherits what that suite writes into the package tree
    // (ADR 0017) and a red reading still costs one extra copy (ADR 0005).
    final template = await baseline.clone();
    prepareWatch.stop();

    final background = await runnerFactory(
      baseline.projectRoot,
      suiteConcurrency,
    ).run();
    if (background.exitCode != 0) {
      final summary = (background.events ?? TestEvents.parse(background.output))
          .summarize();
      final evidence = summary.isEmpty
          ? '${background.output}${background.errorOutput}'
          : summary;
      throw RunAborted(
        'baseline is red; a green suite is a precondition '
        '(ADR 0005). If the sandbox is missing an asset the suite needs, '
        "check the project's gitignore rules: they decide the copy set.\n"
        '$evidence',
      );
    }
    final deadline = deadlineFor(background.duration);
    logger?.info(
      'baseline green in {DurationMs} ms, '
      'deadline {DeadlineMs} ms',
      {
        'DurationMs': background.duration.inMilliseconds,
        'DeadlineMs': deadline.inMilliseconds,
      },
    );

    final routing = await _resolveCoverage(baseline);
    final (mutants, sources, unviable) = await _generate(routing);
    // The earliest point carrying all three of the event's fields: the
    // baseline and its deadline are known above, the count only here.
    _emit(
      RunStarted(
        mutantCount: mutants.length,
        baseline: background.duration,
        deadline: deadline,
      ),
    );

    prepareWatch.start();
    final workers = max(1, min(jobs, mutants.length));
    final sandboxes = [
      template,
      ...await Future.wait([
        for (var i = 1; i < workers; i++) template.clone(),
      ]),
    ];
    final runners = [
      for (final c in sandboxes) runnerFactory(c.projectRoot, suiteConcurrency),
    ];
    prepareWatch.stop();
    logger?.info(
      'prepared {Sandboxes} sandboxes in {DurationMs} ms, '
      '{SuiteConcurrency} test threads each',
      {
        'Sandboxes': sandboxes.length,
        'SuiteConcurrency': suiteConcurrency,
        'DurationMs': prepareWatch.elapsedMilliseconds,
      },
    );
    // One run log per sandbox, named after it (ADR 0016).
    final runLogs = [
      for (final c in sandboxes)
        ButcherLogger(
          verbose: false,
          path: p.join(paths.runLogs, '${c.name}.log'),
          runId: runId,
        ),
    ];

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
          sandboxes[slot],
          runners[slot],
          runLogs[slot],
          deadline,
          unviable,
          routing,
        );
        results[index] = result;
        done++;
        logger?.info('classified {MutantId} as {Outcome} ({Done}/{Total})', {
          'MutantId': result.mutant.id,
          'Outcome': result.outcome.name,
          'Done': done,
          'Total': mutants.length,
          'Worker': slot,
          'Sandbox': sandboxes[slot].name,
          'File': result.mutant.mutation.filePath,
          'Offset': result.mutant.mutation.offset,
          'Operator': result.mutant.mutation.mutatorId,
          'Replacement': result.mutant.mutation.replacement,
          'ExitCode': result.testRun?.exitCode,
          'TimedOut': result.testRun?.timedOut,
          'DurationMs': result.testRun?.duration.inMilliseconds,
        });
        onProgress?.call(done, mutants.length, result);
        _emit(MutantClassified(result));
      }
    }

    await Future.wait([for (var i = 0; i < workers; i++) worker(i)]);
    _emit(const RunCompleted());
    return RunResult(
      results: results.cast<MutantResult>(),
      sources: sources,
      baseline: background.duration,
      deadline: deadline,
    );
  }

  /// Every mutant with its file's pristine source, plus the ids of those that
  /// fail static analysis: a non-compiling mutant needs no evidence from the
  /// suite (ADR 0019).
  ///
  /// The analyzer state lives and dies inside this method, so its resolved
  /// units are collectible before the first worker runs (ADR 0016).
  Future<(List<Mutant>, Map<String, String>, Set<String>)> _generate(
    CoverageProvider coverage,
  ) async {
    final watch = Stopwatch()..start();
    final generator = MutantGenerator(
      projectRoot: projectRoot,
      registry: registry,
      isExcluded: MutationScope.load(projectRoot).excludes,
    );
    final (mutants, sources) = await generator.generate();
    coverage.indexSources(sources);
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
        'DurationMs': watch.elapsedMilliseconds,
      },
    );

    watch.reset();
    final unviable = await ViabilityChecker(
      analysis: generator.analysis,
    ).unviable(mutants.where(coverage.isCovered), sources);
    logger?.info(
      'checked viability of {MutantCount} mutants in {DurationMs} ms; '
      '{UnviableCount} unviable',
      {
        'MutantCount': mutants.length,
        'UnviableCount': unviable.length,
        'DurationMs': watch.elapsedMilliseconds,
      },
    );
    return (mutants, sources, unviable);
  }

  Future<MutantResult> _classify(
    Mutant mutant,
    Sandbox sandbox,
    TestRunner runner,
    ButcherLogger runLog,
    Duration deadline,
    Set<String> unviable,
    CoverageProvider coverage,
  ) async {
    if (!coverage.isCovered(mutant)) {
      return MutantResult(mutant: mutant, outcome: Outcome.noCoverage);
    }
    if (unviable.contains(mutant.id)) {
      return MutantResult(mutant: mutant, outcome: Outcome.unviable);
    }
    try {
      await sandbox.apply(mutant.mutation);
      // Only the suites covering the mutant, cheapest first, in one
      // fail-fast run: the first failure ends it, so an early kill costs the
      // cheap suites only (ADR 0011). An unknown selection runs everything.
      final suites = coverage.suitesFor(mutant);
      final run = await runner.run(
        suites: [for (final suite in suites ?? const <TestSuite>[]) suite.path],
        timeout: _deadlineFor(suites, deadline),
        // One failing test already kills the mutant; the rest is wasted work.
        failFast: true,
      );
      // The whole stream is parsed once here and dropped afterwards; only an
      // excerpt outlives this classification (ADR 0016).
      final events = run.events ?? TestEvents.parse(run.output);
      final result = MutantResult(
        mutant: mutant,
        outcome: const OutcomeClassifier().classify(run, events),
        testRun: _excerpt(run),
      );
      _logMutantRun(runLog, sandbox.name, result, events.errors, suites);
      return result;
      // Expected mutant-level failures are outcomes, never exceptions
      // (ADR 0006); their evidence lands in the run log (ADR 0016).
    } catch (error, stackTrace) {
      if (error is! IOException && error is! StateError) rethrow;
      final result = MutantResult(
        mutant: mutant,
        outcome: Outcome.runError,
        error: '$error\n$stackTrace',
      );
      _logMutantRun(runLog, sandbox.name, result, const [], null);
      return result;
    } finally {
      await sandbox.restore(mutant.mutation.filePath);
    }
  }

  /// Copy of [run] keeping only a bounded excerpt of each stream, since every
  /// mutant's result lives until the run ends (ADR 0016).
  static TestRun _excerpt(TestRun run) => TestRun(
    exitCode: run.exitCode,
    timedOut: run.timedOut,
    output: _cap(run.output),
    errorOutput: _cap(run.errorOutput),
    duration: run.duration,
  );

  static String _cap(String stream) {
    if (stream.length <= outputExcerptLimit) return stream;
    const head = outputExcerptLimit ~/ 2;
    return '${stream.substring(0, head)}\n'
        '[butcher] truncated ${stream.length - outputExcerptLimit} characters\n'
        '${stream.substring(stream.length - outputExcerptLimit + head)}';
  }

  /// Appends one wide event for [result] to its worker's [runLog],
  /// correlated with the tool log through the shared `RunId` (ADR 0016).
  /// [nestedErrors] come from the full stream, of which [result] keeps only
  /// an excerpt.
  void _logMutantRun(
    ButcherLogger runLog,
    String sandbox,
    MutantResult result,
    List<String> nestedErrors,
    List<TestSuite>? suites,
  ) {
    final run = result.testRun;
    final mutation = result.mutant.mutation;
    final properties = {
      'MutantId': result.mutant.id,
      'Sandbox': sandbox,
      'Outcome': result.outcome.name,
      'Mutation': mutation.description,
      'File': mutation.filePath,
      'Offset': mutation.offset,
      'Operator': mutation.mutatorId,
      'Replacement': mutation.replacement,
      'Suites': [for (final suite in suites ?? const <TestSuite>[]) suite.path],
      'SuiteMs': suites?.fold(
        0,
        (total, s) => total + s.duration.inMilliseconds,
      ),
      if (result.error != null) 'Error': result.error,
      if (run != null) ...{
        'ExitCode': run.exitCode,
        'TimedOut': run.timedOut,
        'DurationMs': run.duration.inMilliseconds,
        'Output': run.output,
        'ErrorOutput': run.errorOutput,
      },
    };
    if (failedOutcomes.contains(result.outcome)) {
      runLog.error('mutant run failed: {MutantId} as {Outcome}', properties);
    } else {
      runLog.info('mutant run completed: {MutantId} as {Outcome}', properties);
    }
    for (final error in nestedErrors) {
      runLog.error('nested test error: {Error}', {'Error': error});
    }
  }

  /// Deadline of a routed run: whichever of the selection's own serial cost
  /// and the [wholeSuite] reading is longer, both on the `× 3` rule. ADR 0006
  /// records the self-run receipt that rules out taking the reading alone.
  static Duration _deadlineFor(List<TestSuite>? suites, Duration wholeSuite) {
    if (suites == null) return wholeSuite;
    final selected = deadlineFor(
      suites.fold(Duration.zero, (total, suite) => total + suite.duration),
    );
    return selected > wholeSuite ? selected : wholeSuite;
  }

  /// Per-mutant timeout: `max(background × 3, 10 s floor)` (ADR 0006).
  static Duration deadlineFor(Duration background) {
    const floor = Duration(seconds: 10);
    final scaled = background * 3;
    return Duration(
      microseconds: max(scaled.inMicroseconds, floor.inMicroseconds),
    );
  }

  /// Resolves the project before it is copied or analysed: a stale package
  /// configuration would otherwise yield only unviable mutants (ADR 0020).
  Future<void> _provision() async {
    // A missing or non-package root reports better from the copy and
    // sandbox stages than from `pub get` here.
    if (!File(p.join(projectRoot, 'pubspec.yaml')).existsSync()) return;
    final watch = Stopwatch()..start();
    await pubGet(projectRoot, label: 'the project');
    logger?.info('provisioned {ProjectRoot} in {DurationMs} ms', {
      'ProjectRoot': projectRoot,
      'DurationMs': watch.elapsedMilliseconds,
    });
  }

  /// The routing coverage: the supplied provider, or one collected by an
  /// extra instrumented run of the green suite (ADR 0020). It reuses the
  /// baseline sandbox, which the workers no longer clone from, so none
  /// of them inherits the coverage artefacts.
  Future<CoverageProvider> _resolveCoverage(Sandbox baseline) async {
    final supplied = coverage;
    if (supplied != null) return supplied;
    final watch = Stopwatch()..start();
    // Nothing else runs during collection and its duration calibrates
    // nothing, so it uses every core instead of one job's share.
    final collected = await CoverageCollector(
      root: baseline.projectRoot,
      packageConfigRoot: baseline.root,
      outputDir: p.join(baseline.projectRoot, coverageDirName),
    ).collect(runnerFactory(baseline.projectRoot, Platform.numberOfProcessors));
    logger
        ?.info('collected coverage for {FileCount} files in {DurationMs} ms', {
          'FileCount': collected.merged.hits.length,
          'DurationMs': watch.elapsedMilliseconds,
        });
    return collected;
  }
}
