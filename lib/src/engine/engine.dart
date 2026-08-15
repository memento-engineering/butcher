import 'dart:io';
import 'dart:math';

import '../model/mutant.dart';
import '../model/mutant_result.dart';
import '../model/outcome.dart';
import '../mutagens/mutagen_registry.dart';
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

/// Orchestrates a full run: generate, contain, verify, irradiate, classify.
final class Engine {
  /// Creates an engine for the project at [projectRoot].
  Engine({
    required this.projectRoot,
    MutagenRegistry? registry,
    this.coverage = const FullCoverageProvider(),
    this.selector = const WholeSuiteSelector(),
    this.runnerFactory = DartTestRunner.new,
    this.onProgress,
    int? jobs,
  }) : registry = registry ?? MutagenRegistry.defaults(),
       jobs = jobs ?? defaultJobs;

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
  final TestRunner Function(String root) runnerFactory;

  /// Optional per-mutant progress hook, called in completion order.
  final ProgressCallback? onProgress;

  /// Number of parallel workers, each owning a containment (ADR 0017).
  final int jobs;

  /// Runs the whole pipeline and returns every classified result.
  Future<RunResult> run() async {
    final (mutants, sources) = await MutantGenerator(
      projectRoot: projectRoot,
      registry: registry,
    ).generate();

    final workers = max(1, min(jobs, mutants.length));
    final containments = await Future.wait([
      for (var i = 0; i < workers; i++) Containment.create(projectRoot),
    ]);
    try {
      await Future.wait(containments.map((c) => _resolveDependencies(c.root)));
      final runners = [for (final c in containments) runnerFactory(c.root)];

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
