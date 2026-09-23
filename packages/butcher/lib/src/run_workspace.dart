import 'dart:io';

import 'package:path/path.dart' as p;

import 'engine/sandbox.dart';
import 'engine/run_aborted.dart';
import 'butcher_paths.dart';

/// Exclusive ownership of the butcher workspace for one run (ADR 0018).
///
/// Acquiring takes the lock; an actively held lock is never stolen. [clean]
/// then removes what earlier runs left behind, so evidence survives until the
/// next run starts instead of being destroyed at exit.
final class RunWorkspace {
  /// Takes the exclusive lock for [paths]; aborts when it is already held.
  factory RunWorkspace.acquire(ButcherPaths paths) {
    final lock = File(paths.lockFile)..parent.createSync(recursive: true);
    try {
      lock.createSync(exclusive: true);
    } on FileSystemException {
      throw RunAborted(
        'another butcher run holds ${paths.lockFile}. Wait for it to finish, or '
        'delete the lock file if the run that left it is gone.',
      );
    }
    return RunWorkspace._(paths);
  }

  RunWorkspace._(this.paths);

  /// Filesystem locations this workspace owns.
  final ButcherPaths paths;

  /// Removes the previous tool log, leftover sandboxes, and every run log,
  /// keeping the run-log directory itself; aborts when a target survives.
  ///
  /// A failed cleanup releases the lock: the run never started, so leaving it
  /// behind would only make later runs report a conflict that does not exist.
  void clean() {
    try {
      final toolLog = File(paths.toolLog);
      if (toolLog.existsSync()) toolLog.deleteSync();
      for (final entry in Directory(paths.root).listSync()) {
        if (p.basename(entry.path).startsWith(sandboxPrefix)) {
          entry.deleteSync(recursive: true);
        }
      }
      final runLogs = Directory(paths.runLogs)..createSync(recursive: true);
      for (final entry in runLogs.listSync()) {
        entry.deleteSync(recursive: true);
      }
    } on FileSystemException catch (error) {
      release();
      throw RunAborted(
        'startup cleanup failed for ${error.path}: ${error.message}',
      );
    }
  }

  /// Releases the lock; a crashed run leaves it behind as evidence.
  void release() {
    final lock = File(paths.lockFile);
    if (lock.existsSync()) lock.deleteSync();
  }
}
