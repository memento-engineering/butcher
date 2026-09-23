import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';

import '../model/mutant.dart';
import '../model/mutation.dart';
import 'project_analysis.dart';

/// Statically verifies that mutants compile before any test run (ADR 0019).
///
/// Re-resolves the mutated file through an in-memory overlay on the shared
/// [ProjectAnalysis]; only the mutated file needs analysis because every
/// current mutator rewrites expressions inside bodies, which cannot change a
/// file's API.
final class ViabilityChecker {
  /// Creates a checker over the already resolved [analysis].
  ViabilityChecker({required this.analysis});

  /// Analyzer state shared with mutant generation.
  final ProjectAnalysis analysis;

  var _stamp = 0;

  /// Ids of the [mutants] that do not compile against their [sources].
  ///
  /// Mutants are grouped by file so a file's overlay is restored once per
  /// batch instead of between every two mutants of that file.
  Future<Set<String>> unviable(
    Iterable<Mutant> mutants,
    Map<String, String> sources,
  ) async {
    final batches = <String, List<Mutant>>{};
    for (final mutant in mutants) {
      final file = mutant.mutation.filePath;
      if (sources.containsKey(file)) {
        batches.putIfAbsent(file, () => []).add(mutant);
      }
    }
    final rejected = <String>{};
    for (final MapEntry(key: file, value: batch) in batches.entries) {
      final pristine = sources[file]!;
      final path = analysis.absolutePath(file);
      final context = analysis.collection.contextFor(path);
      try {
        for (final mutant in batch) {
          if (!await _compiles(context, path, mutant.mutation, pristine)) {
            rejected.add(mutant.id);
          }
        }
      } finally {
        analysis.provider.removeOverlay(path);
        await _invalidate(context, path);
      }
    }
    return rejected;
  }

  Future<bool> _compiles(
    AnalysisContext context,
    String path,
    Mutation mutation,
    String pristine,
  ) async {
    analysis.provider.setOverlay(
      path,
      content: pristine.replaceRange(
        mutation.offset,
        mutation.offset + mutation.length,
        mutation.replacement,
      ),
      modificationStamp: _stamp++,
    );
    await _invalidate(context, path);
    final result = await context.currentSession.getErrors(path);
    if (result is! ErrorsResult) return false;
    return !result.diagnostics.any(_deniesCompilation);
  }

  static Future<void> _invalidate(AnalysisContext context, String path) async {
    context.changeFile(path);
    await context.applyPendingFileChanges();
  }

  /// Compile-time and syntax errors block compilation; warnings, lints, and
  /// lints escalated to error severity do not.
  static bool _deniesCompilation(Diagnostic diagnostic) {
    final type = diagnostic.diagnosticCode.type;
    return type == DiagnosticType.COMPILE_TIME_ERROR ||
        type == DiagnosticType.SYNTACTIC_ERROR;
  }
}
