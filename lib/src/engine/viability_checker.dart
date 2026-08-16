import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import '../model/mutation.dart';

/// Statically verifies that a mutant compiles before any test run (ADR 0019).
///
/// Re-resolves the mutated file through an in-memory overlay; only the
/// mutated file needs analysis because every current mutagen rewrites
/// expressions inside bodies, which cannot change a file's API.
final class ViabilityChecker {
  /// Creates a checker for the project at [projectRoot].
  ViabilityChecker({required this.projectRoot});

  /// Absolute or relative path of the project under test.
  final String projectRoot;

  final _provider = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
  AnalysisContextCollection? _collection;
  var _stamp = 0;

  /// Whether [mutation] applied to the [pristine] source compiles.
  Future<bool> compiles(Mutation mutation, String pristine) async {
    final path = p.normalize(p.absolute(projectRoot, mutation.filePath));
    final mutated = pristine.replaceRange(
      mutation.offset,
      mutation.offset + mutation.length,
      mutation.replacement,
    );
    final collection = _collection ??= AnalysisContextCollection(
      includedPaths: [p.normalize(p.absolute(projectRoot, 'lib'))],
      resourceProvider: _provider,
    );
    final context = collection.contextFor(path);
    _provider.setOverlay(path, content: mutated, modificationStamp: _stamp++);
    try {
      context.changeFile(path);
      await context.applyPendingFileChanges();
      final result = await context.currentSession.getErrors(path);
      if (result is! ErrorsResult) return false;
      return !result.diagnostics.any(_deniesCompilation);
    } finally {
      _provider.removeOverlay(path);
      context.changeFile(path);
      await context.applyPendingFileChanges();
    }
  }

  /// Compile-time and syntax errors block compilation; warnings, lints, and
  /// lints escalated to error severity do not.
  static bool _deniesCompilation(Diagnostic diagnostic) {
    final type = diagnostic.diagnosticCode.type;
    return type == DiagnosticType.COMPILE_TIME_ERROR ||
        type == DiagnosticType.SYNTACTIC_ERROR;
  }
}
