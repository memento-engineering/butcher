import 'dart:io';

import 'posix_interlock.dart';
import 'windows_interlock.dart';

/// Owns the spawn and the kill of one process tree.
///
/// The interlock starts the process itself so that the started process is a
/// kill boundary the moment it exists: a job object on Windows, a process
/// group on POSIX. Everything the process starts afterwards is inside that
/// boundary, so [terminate] is one call with nothing to list and nothing to
/// race.
abstract interface class ProcessInterlock {
  /// The implementation for the host platform.
  static ProcessInterlock create() =>
      Platform.isWindows ? WindowsInterlock() : PosixInterlock();

  /// Starts [executable] with [arguments] inside the interlock, optionally in
  /// [workingDirectory].
  ///
  /// The returned process is admitted before the caller can drain a stream of
  /// it, so nothing it spawns can escape.
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });

  /// Kills [process] and everything it started, then awaits its exit code.
  Future<void> terminate(Process process);

  /// Releases whatever the interlock holds. Safe to call more than once.
  void dispose();
}
