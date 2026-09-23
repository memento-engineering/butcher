@Timeout(Duration(minutes: 1))
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:butcher/src/cli/cli.dart';
import 'package:butcher/src/cli/signal_watcher.dart';
import 'package:test/test.dart';

import '../helpers/paths.dart';

/// Signals a test raises itself, recording what a watcher subscribed to, what
/// it cancelled, and how it ended the process.
final class RecordedSignals {
  final subscribed = <ProcessSignal>[];
  final cancelled = <ProcessSignal>[];
  final exits = <int>[];
  final _controllers = <ProcessSignal, StreamController<ProcessSignal>>{};

  /// A watcher over these signals instead of the process's own.
  SignalWatcher watcher() => SignalWatcher(
    watch: (signal) {
      subscribed.add(signal);
      final controller = StreamController<ProcessSignal>();
      controller.onCancel = () => cancelled.add(signal);
      _controllers[signal] = controller;
      return controller.stream;
    },
    quit: exits.add,
  );

  /// Delivers [signal] to whatever the watcher installed for it.
  void raise(ProcessSignal signal) => _controllers[signal]!.add(signal);
}

void main() {
  test('registers the handler for the run and unregisters it after', () async {
    final signals = RecordedSignals();
    final paths = await isolatedButcherPaths('butcher_signal_');

    await expectLater(
      butcherMain(
        [p.join(paths.root, 'no_such_project')],
        out: StringBuffer(),
        paths: paths,
        signals: signals.watcher(),
      ),
      throwsA(isA<FileSystemException>()),
    );
    await pumpEventQueue();

    expect(
      signals.subscribed,
      SignalWatcher.defaultSignals.keys,
      reason: 'the run is watched from the moment it holds the lock',
    );
    expect(
      signals.cancelled,
      unorderedEquals(signals.subscribed),
      reason: 'a finished run leaves the signals reaching the process again',
    );
  });

  test('reaps on a signal and exits with its conventional code', () async {
    final signals = RecordedSignals();
    // Nothing supervised is live, which terminate-all has to survive: the
    // run may be signalled before it starts its first suite.
    final watcher = signals.watcher()..start();

    signals.raise(ProcessSignal.sigint);
    await pumpEventQueue();

    expect(signals.exits, [130]);
    expect(watcher.watching, isFalse, reason: 'the handler reaps once');
  });

  test('installs its handler once', () {
    final signals = RecordedSignals();
    final watcher = signals.watcher()
      ..start()
      ..start();

    expect(signals.subscribed, SignalWatcher.defaultSignals.keys);

    watcher.stop();
    expect(watcher.watching, isFalse);
  });
}
