/// The `FileResult` type of the mutation-testing report schema.
library;

import 'equality.dart';
import 'json_object.dart';
import 'report_mutant.dart';

/// One mutated file's entry in a report.
///
/// The key this entry sits under in the report's `files` dictionary is the
/// file's path relative to the project root; the entry itself carries no path.
/// All three fields are required: a report that names a file without its
/// pristine source cannot render what each mutant changed.
final class FileResult {
  /// Creates the entry for a mutated file.
  const FileResult({
    required this.language,
    required this.source,
    required this.mutants,
  });

  /// The schema fields a file result must carry.
  static const requiredJsonFields = <String>{'language', 'source', 'mutants'};

  /// The schema fields a file result may carry.
  static const optionalJsonFields = <String>{};

  /// Reads a file result from decoded JSON.
  static FileResult fromJson(Object? json) {
    final object = JsonObject.read(json, 'FileResult');
    return FileResult(
      language: object.requiredString('language'),
      source: object.requiredString('source'),
      mutants: object.requiredList('mutants', ReportMutant.fromJson),
    );
  }

  /// The programming language, used for syntax highlighting in a report.
  final String language;

  /// The full source of the original file, without any mutant applied.
  final String source;

  /// Every mutant generated in this file, in the producer's order.
  final List<ReportMutant> mutants;

  /// Writes this file result as decoded JSON.
  Map<String, Object?> toJson() => <String, Object?>{
    'language': language,
    'source': source,
    'mutants': <Object?>[for (final mutant in mutants) mutant.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is FileResult &&
      other.language == language &&
      other.source == source &&
      deepEquals(other.mutants, mutants);

  @override
  int get hashCode => Object.hash(language, source, deepHash(mutants));

  @override
  String toString() =>
      'FileResult(language: $language, mutants: ${mutants.length}, '
      'source: ${source.length} characters)';
}
