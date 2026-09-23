/// The package's two parse entry points.
library;

import 'dart:convert';

import 'json_object.dart';
import 'mutation_test_result.dart';

/// Parses [source], a mutation-testing report as JSON text.
///
/// Decodes [source] and delegates to [parseMutationTestReportJson], so the two
/// entry points cannot drift apart. Throws a [FormatException] naming the
/// violated requirement when the document does not satisfy the schema.
MutationTestResult parseMutationTestReport(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw FormatException(
      'A mutation-testing report must be a JSON object, but found '
      '${describeJson(decoded)}.',
      source,
    );
  }
  return parseMutationTestReportJson(decoded);
}

/// Parses [json], an already-decoded mutation-testing report.
///
/// A consumer holding a decoded document — one map out of a larger payload,
/// say — parses it here rather than encoding it again to reach
/// [parseMutationTestReport]. Throws a [FormatException] naming the violated
/// requirement.
MutationTestResult parseMutationTestReportJson(Map<String, Object?> json) =>
    MutationTestResult.fromJson(json);
