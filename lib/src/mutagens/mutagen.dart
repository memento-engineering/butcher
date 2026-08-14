/// A mutation operator: declares node kind, guard, and replacements.
///
/// Mutagens emit Mutation value objects; they never traverse the AST or
/// execute anything.
abstract interface class Mutagen {
  /// Operator id used in reports and stable mutant ids.
  String get id;
}
