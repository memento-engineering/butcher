import 'dart:async';
import 'dart:io';

import 'package:butcher_process/butcher_process.dart';

/// Reaps every supervised process when the run is signalled.
///
/// Each suite leads a process group of its own (ADR 0022), so an interrupt at
/// the terminal no longer reaps them along with the tool: without this
/// handler an interrupted run leaks every in-flight suite. Reaping goes
/// through the process package's registry, so the handler needs no reference
/// to the engine's worker pool.
final class SignalWatcher {
  /// Creates a watcher over [signals], each mapped to its signal number.
  ///
  /// [watch] subscribes to a signal and [quit] ends the process; both are
  /// seams for tests.
  SignalWatcher({
    Map<ProcessSignal, int>? signals,
    Stream<ProcessSignal> Function(ProcessSignal signal)? watch,
    void Function(int code)? quit,
  }) : _signals = signals ?? defaultSignals,
       _watch = watch ?? ((signal) => signal.watch()),
       _quit = quit ?? exit;

  /// Interrupt and terminate, the two a run is stopped with.
  ///
  /// Windows raises on anything but an interrupt, so it watches that alone.
  static final Map<ProcessSignal, int> defaultSignals = {
    ProcessSignal.sigint: 2,
    if (!Platform.isWindows) ProcessSignal.sigterm: 15,
  };

  final Map<ProcessSignal, int> _signals;
  final Stream<ProcessSignal> Function(ProcessSignal signal) _watch;
  final void Function(int code) _quit;
  final _subscriptions = <StreamSubscription<ProcessSignal>>[];

  /// Whether the handler is installed.
  bool get watching => _subscriptions.isNotEmpty;

  /// Installs the handler; a second call while it is installed does nothing.
  void start() {
    if (watching) return;
    for (final signal in _signals.keys) {
      _subscriptions.add(_watch(signal).listen(_reap));
    }
  }

  /// Removes the handler, so the signals reach the process normally again.
  void stop() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  Future<void> _reap(ProcessSignal signal) async {
    stop();
    await terminateAllSupervisedProcesses();
    // 128 plus the signal number is the shell's convention for a signalled
    // exit, and is what a caller reads the interrupt back out of.
    _quit(128 + _signals[signal]!);
  }
}
