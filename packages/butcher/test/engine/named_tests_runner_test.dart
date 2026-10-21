import 'package:butcher/src/engine/named_tests_runner.dart';
import 'package:butcher/src/engine/test_runner.dart';
import 'package:butcher/src/model/test_run.dart';
import 'package:test/test.dart';

/// Records the suites of every run.
final class _RecordingRunner implements TestRunner {
  final runs = <List<String>>[];

  @override
  Future<TestRun> run({
    List<String> suites = const [],
    Duration? timeout,
    bool failFast = false,
    String? coverageDir,
  }) async {
    runs.add(suites);
    return const TestRun(
      exitCode: 0,
      timedOut: false,
      output: '',
      duration: Duration.zero,
    );
  }
}

void main() {
  test('runs the named tests in place of the whole suite', () async {
    final inner = _RecordingRunner();
    final runner = NamedTestsRunner(inner, const ['test/all_tests.dart']);

    await runner.run();
    await runner.run(suites: const ['test/a_test.dart']);

    expect(inner.runs, [
      ['test/all_tests.dart'],
      ['test/a_test.dart'],
    ]);
  });
}
