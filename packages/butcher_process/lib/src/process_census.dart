import 'dart:io';

/// How many processes the host is running right now.
///
/// A diagnostic, never a kill path: it answers "did that run leak processes",
/// and nothing here is derived from it or acted on. POSIX counts a process
/// listing, Windows counts the management query. Returns `0` when the host
/// cannot be asked, which is indistinguishable from an empty host and is why
/// this is only ever compared against another reading taken the same way.
Future<int> hostProcessCount() async {
  try {
    final listed = await Process.run(
      Platform.isWindows ? 'powershell' : 'ps',
      Platform.isWindows
          ? const [
              '-NoProfile',
              '-NonInteractive',
              '-Command',
              '(Get-CimInstance Win32_Process).Count',
            ]
          : const ['-A', '-o', 'pid='],
    );
    final output = '${listed.stdout}';
    return Platform.isWindows
        ? int.tryParse(output.trim()) ?? 0
        : output.split('\n').where((line) => line.trim().isNotEmpty).length;
  } on ProcessException {
    return 0;
  }
}
