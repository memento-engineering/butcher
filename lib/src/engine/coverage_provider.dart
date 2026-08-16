import '../model/mutant.dart';

/// Which mutants the test suite can reach at all.
///
/// Seam for the v1.0 tracer; the MVP default is [FullCoverageProvider] in
/// full_coverage_provider.dart.
abstract interface class CoverageProvider {
  /// Whether any test executes the source [mutant] changes.
  bool isCovered(Mutant mutant);

  /// Receives the generation-time pristine [sources] (project-relative posix
  /// path to content) before any [isCovered] call, so offsets and lines map
  /// against the same snapshot the mutants came from.
  void indexSources(Map<String, String> sources);
}
