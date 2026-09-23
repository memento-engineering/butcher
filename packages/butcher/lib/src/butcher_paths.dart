import 'dart:io';

import 'package:path/path.dart' as p;

/// All filesystem locations used by one butcher invocation.
final class ButcherPaths {
  /// Resolves every path once below [root].
  ButcherPaths({required String root})
    : root = p.normalize(p.absolute(root)),
      toolLog = p.normalize(p.absolute(p.join(root, 'butcher.log'))),
      runLogs = p.normalize(p.absolute(p.join(root, 'runs'))),
      lockFile = p.normalize(p.absolute(p.join(root, '.lock')));

  /// Production paths below the system temp directory.
  factory ButcherPaths.systemTemp() =>
      ButcherPaths(root: p.join(Directory.systemTemp.path, 'butcher'));

  /// Production paths, redirected to `BUTCHER_TEMP` when it is non-empty.
  factory ButcherPaths.production({Map<String, String>? environment}) {
    final override = (environment ?? Platform.environment)['BUTCHER_TEMP'];
    return override == null || override.isEmpty
        ? ButcherPaths.systemTemp()
        : ButcherPaths(root: override);
  }

  /// Root for sandboxes and logs.
  final String root;

  /// Tool-wide CLEF log file.
  final String toolLog;

  /// Directory containing one CLEF log per sandbox.
  final String runLogs;

  /// Exclusive lock held for the duration of a run (ADR 0018).
  final String lockFile;
}
