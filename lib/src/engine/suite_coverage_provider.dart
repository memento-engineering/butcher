import '../model/mutant.dart';
import '../model/test_suite.dart';
import 'coverage_provider.dart';
import 'lcov_coverage_provider.dart';

/// Per-line coverage that still knows which test file recorded it, so a
/// mutant runs against its covering suites only (ADR 0011).
final class SuiteCoverageProvider implements CoverageProvider {
  /// Routes over [merged] hits, [perSuite] being each suite's hit lines per
  /// file and [durations] what each suite cost; a suite the collection run
  /// did not time falls back to [wholeRun] and sorts last.
  SuiteCoverageProvider({
    required this.merged,
    required Map<String, Map<String, Set<int>>> perSuite,
    required Map<String, Duration> durations,
    required Duration wholeRun,
  }) : _suites = [
         for (final entry in perSuite.entries)
           (
             suite: TestSuite(
               path: entry.key,
               duration: durations[entry.key] ?? wholeRun,
             ),
             files: entry.value,
           ),
       ]..sort((a, b) => a.suite.duration.compareTo(b.suite.duration));

  /// Every suite's hits merged; answers what is covered at all.
  final LcovCoverageProvider merged;

  final List<({TestSuite suite, Map<String, Set<int>> files})> _suites;

  @override
  void indexSources(Map<String, String> sources) =>
      merged.indexSources(sources);

  @override
  bool isCovered(Mutant mutant) => merged.isCovered(mutant);

  @override
  List<TestSuite>? suitesFor(Mutant mutant) {
    final file = mutant.mutation.filePath;
    final line = merged.lineOf(mutant);
    // A line no report records is not an executable statement of its own, so
    // it inherits its file's verdict: every suite that loaded the file.
    final executable = merged.hits[file]?.containsKey(line) ?? false;
    final covering = [
      for (final entry in _suites)
        if (entry.files[file] case final lines?)
          if (!executable || lines.contains(line)) entry.suite,
    ];
    // Routing may never under-select: an empty selection runs everything.
    return covering.isEmpty ? null : covering;
  }
}
