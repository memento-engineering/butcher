import '../model/mutant.dart';
import 'test_selector.dart';

/// MVP default: run the whole suite against every mutant.
final class WholeSuiteSelector implements TestSelector {
  /// Creates the selector; it holds no state.
  const WholeSuiteSelector();

  @override
  List<String>? select(Mutant mutant) => null;
}
