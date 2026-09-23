import 'dart:async';
import 'dart:io';

import 'process_interlock.dart';

/// A process whose whole tree has one owner.
///
/// Every instance holds its own [ProcessInterlock] and registers itself while
/// it is alive, so [terminateAllSupervisedProcesses] can reap the tree of a
/// run without a handle on whatever pool started it.
final class SupervisedProcess {
  SupervisedProcess._(this._process, this._interlock);

  /// Starts [executable] with [arguments] under a fresh interlock, optionally
  /// in [workingDirectory].
  static Future<SupervisedProcess> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final interlock = ProcessInterlock.create();
    final process = await interlock.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    final supervised = SupervisedProcess._(process, interlock);
    _live.add(supervised);
    return supervised;
  }

  /// Every started process that has neither exited nor been killed, shared by
  /// all instances.
  static final Set<SupervisedProcess> _live = {};

  final Process _process;
  final ProcessInterlock _interlock;
  bool _released = false;

  /// The pid of the started process, which leads the tree.
  int get pid => _process.pid;

  /// The process's standard output, for the caller to drain.
  Stream<List<int>> get output => _process.stdout;

  /// The process's standard error, for the caller to drain.
  Stream<List<int>> get errorOutput => _process.stderr;

  /// The exit code, or `null` when [deadline] passed and the tree was killed.
  ///
  /// Either way the interlock is released before this returns.
  Future<int?> wait({Duration? deadline}) async {
    try {
      final code = deadline == null
          ? await _process.exitCode
          : await _process.exitCode.timeout(deadline);
      _release();
      return code;
    } on TimeoutException {
      await kill();
      return null;
    }
  }

  /// Kills the process and everything it started. Safe to call more than once,
  /// and always releases the interlock.
  Future<void> kill() async {
    if (_released) return;
    await _interlock.terminate(_process);
    _release();
  }

  void _release() {
    if (_released) return;
    _released = true;
    _live.remove(this);
    _interlock.dispose();
  }
}

/// Kills every supervised process still running, whoever started it.
///
/// The entry point a signal handler needs: it reaches the registry directly,
/// so the handler needs no reference to the pool the processes came from.
Future<void> terminateAllSupervisedProcesses() async {
  await Future.wait([
    for (final supervised in SupervisedProcess._live.toList())
      supervised.kill(),
  ]);
}
