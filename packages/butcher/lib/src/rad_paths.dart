import 'dart:io';

import 'package:path/path.dart' as p;

/// All filesystem locations used by one rad invocation.
final class RadPaths {
  /// Resolves every path once below [root].
  RadPaths({required String root})
    : root = p.normalize(p.absolute(root)),
      toolLog = p.normalize(p.absolute(p.join(root, 'rad.log'))),
      runLogs = p.normalize(p.absolute(p.join(root, 'runs'))),
      lockFile = p.normalize(p.absolute(p.join(root, '.lock')));

  /// Production paths below the system temp directory.
  factory RadPaths.systemTemp() =>
      RadPaths(root: p.join(Directory.systemTemp.path, 'rad'));

  /// Production paths, redirected to `RAD_TEMP` when it is non-empty.
  factory RadPaths.production({Map<String, String>? environment}) {
    final override = (environment ?? Platform.environment)['RAD_TEMP'];
    return override == null || override.isEmpty
        ? RadPaths.systemTemp()
        : RadPaths(root: override);
  }

  /// Root for containments and logs.
  final String root;

  /// Tool-wide CLEF log file.
  final String toolLog;

  /// Directory containing one CLEF log per containment.
  final String runLogs;

  /// Exclusive lock held for the duration of a run (ADR 0018).
  final String lockFile;
}
