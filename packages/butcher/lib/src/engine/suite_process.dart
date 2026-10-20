import 'dart:convert';

import 'package:butcher_process/butcher_process.dart';

import '../model/test_events.dart';
import '../model/test_run.dart';
import 'capped_output.dart';

/// Characters retained from stdout. Every verdict is parsed out of this
/// stream, so the bound sits above any real suite (~16k tests' events) and
/// only catches a runaway mutant.
const suiteStdoutLimit = 8 * 1024 * 1024;

/// Characters retained from stderr; nothing is parsed from it.
const suiteStderrLimit = 256 * 1024;

/// Runs one JSON-reporting suite process, [executable] with [arguments] in
/// [root], killed with everything it spawned after [timeout] if set.
Future<TestRun> runSuite(
  String executable,
  List<String> arguments, {
  required String root,
  Duration? timeout,
}) async {
  final watch = Stopwatch()..start();
  // The suite is a kill boundary from the moment it exists, so what it
  // spawns afterwards dies with it in one call (ADR 0022).
  final process = await SupervisedProcess.start(
    executable,
    arguments,
    workingDirectory: root,
  );

  const decoder = Utf8Decoder(allowMalformed: true);
  final output = CappedOutput(limit: suiteStdoutLimit);
  final errors = CappedOutput(limit: suiteStderrLimit);
  final events = TestEvents();
  final drained = Future.wait([
    process.output.transform(decoder).forEach((chunk) {
      events.add(chunk);
      output.write(chunk);
    }),
    process.errorOutput.transform(decoder).forEach(errors.write),
  ]);

  final code = await process.wait(deadline: timeout);
  await drained.timeout(const Duration(seconds: 5), onTimeout: () => []);
  events.close();

  return TestRun(
    // A deadline leaves no exit code to report; the classifier reads the
    // timeout marker instead.
    exitCode: code ?? -1,
    timedOut: code == null,
    output: output.toString(),
    errorOutput: errors.toString(),
    events: events,
    duration: watch.elapsed,
  );
}
