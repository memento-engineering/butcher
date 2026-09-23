@Timeout(Duration(minutes: 1))
library;

import 'package:butcher_process/butcher_process.dart';
import 'package:test/test.dart';

void main() {
  test('counts the processes on the host', () async {
    expect(await hostProcessCount(), greaterThan(0));
  });

  test('the count rises when processes start', () async {
    final before = await hostProcessCount();
    final started = [
      for (var child = 0; child < 8; child++)
        await SupervisedProcess.start('/bin/sh', ['-c', 'sleep 120']),
    ];
    addTearDown(terminateAllSupervisedProcesses);

    expect(
      await hostProcessCount(),
      greaterThan(before),
      reason: '${started.length} new processes outweigh the host churn',
    );
  }, testOn: 'posix');
}
