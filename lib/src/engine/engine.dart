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
  Mutant mutant,
  Outcome outcome,
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
  }) : registry = registry ?? MutagenRegistry.defaults();

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

  /// Optional per-mutant progress hook.
  final ProgressCallback? onProgress;

  /// Runs the whole pipeline and returns every classified result.
  Future<RunResult> run() async {
    final mutants = await MutantGenerator(
      projectRoot: projectRoot,
      registry: registry,
    ).generate();

    final containment = await Containment.create(projectRoot);
    try {
      await _resolveDependencies(containment.root);
      final runner = runnerFactory(containment.root);

      final background = await runner.run();
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

      final results = <MutantResult>[];
      for (final mutant in mutants) {
        final outcome = await _classify(mutant, containment, runner, halfLife);
        results.add(MutantResult(mutant: mutant, outcome: outcome));
        onProgress?.call(results.length, mutants.length, mutant, outcome);
      }
      return RunResult(
        results: results,
        backgroundReading: background.duration,
        halfLife: halfLife,
      );
    } finally {
      await containment.dispose();
    }
  }

  Future<Outcome> _classify(
    Mutant mutant,
    Containment containment,
    TestRunner runner,
    Duration halfLife,
  ) async {
    if (!coverage.isCovered(mutant)) return Outcome.noCoverage;
    try {
      await containment.apply(mutant.mutation);
      final run = await runner.run(
        tests: selector.select(mutant),
        timeout: halfLife,
      );
      return const OutcomeClassifier().classify(run);
    } catch (_) {
      // Mutant-level failures are outcomes, never exceptions (ADR 0006).
      return Outcome.runError;
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
