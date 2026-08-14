import '../model/mutant.dart';

/// Picks the tests to run against one mutant.
///
/// Seam for v1.0 coverage routing; the MVP default is [WholeSuiteSelector] in
/// whole_suite_selector.dart.
abstract interface class TestSelector {
  /// Test names to run; `null` selects the whole suite.
  List<String>? select(Mutant mutant);
}
