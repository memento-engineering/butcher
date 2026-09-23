/// The `MutantStatus` enumeration of the mutation-testing report schema.
library;

/// The result of testing one mutant, as the report schema spells it.
///
/// The eight values are the schema's enumeration in full. [pending] is here
/// even though butcher never emits it: a consumer writing an exhaustive switch
/// over this enum must not break the day it reads a report from a different
/// producer, and modelling the schema faithfully is the point of this package.
enum MutantStatus {
  /// A test failed on the mutant, so the suite detects the change.
  killed('Killed'),

  /// Every covering test passed on the mutant, so the change went unnoticed.
  survived('Survived'),

  /// No test covers the mutated code at all.
  noCoverage('NoCoverage'),

  /// The mutated source did not compile.
  compileError('CompileError'),

  /// The mutant run failed for a reason other than a test assertion.
  runtimeError('RuntimeError'),

  /// The mutant run exceeded its deadline.
  timeout('Timeout'),

  /// The mutant was deliberately excluded from the run.
  ignored('Ignored'),

  /// The mutant has not been tested yet.
  ///
  /// Emitted by producers that stream an incremental report; butcher never
  /// writes it.
  pending('Pending');

  const MutantStatus(this.wireName);

  /// The exact spelling this status has in a report document.
  final String wireName;

  /// The status whose [wireName] is [value].
  ///
  /// Throws a [FormatException] naming [value] when it is not one of the
  /// schema's eight statuses.
  static MutantStatus fromWireName(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    throw FormatException(
      'MutantStatus "$value" is not one of '
      '${values.map((status) => status.wireName).join(', ')}.',
    );
  }
}
