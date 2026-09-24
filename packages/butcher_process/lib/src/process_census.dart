import 'dart:convert';
import 'dart:io';

/// How many processes the host is running right now.
///
/// A diagnostic, never a kill path and never a gate: a whole-host reading
/// cannot tell a run's own descendants from anything else the machine spawns,
/// so it can neither prove a leak nor prove its absence. [pidsInsideBoundaries]
/// is what a leak is judged by. POSIX counts a process listing, Windows counts
/// the management query. Returns `0` when the host cannot be asked, which is
/// indistinguishable from an empty host and is why this is only ever compared
/// against another reading taken the same way.
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

/// The live pids inside the kill boundaries led by [leaders].
///
/// Read-only accounting over a single listing: nothing here kills, and the
/// answer holds only processes the run is responsible for, so nothing else on
/// the host can move it. On POSIX a boundary is the process group the started
/// pid leads, and a process belongs when its group is one of [leaders]. On
/// Windows a boundary is the job the started pid was admitted to, whose live
/// membership is read through the parent chain, because every process a
/// member starts is admitted with it.
///
/// A descendant that leaves its boundary — a POSIX session of its own, a
/// Windows process the listing no longer links to a member — is outside this
/// census by design. It is outside the kill for the same reason, so counting
/// it would claim a reach the interlock does not have.
///
/// Returns an empty set when the host cannot be asked.
Future<Set<int>> pidsInsideBoundaries(Set<int> leaders) async {
  if (leaders.isEmpty) return const {};
  try {
    return Platform.isWindows
        ? await _jobMembers(leaders)
        : await _groupMembers(leaders);
  } on ProcessException {
    return const {};
  }
}

/// Every live pid whose process group is one of [leaders].
Future<Set<int>> _groupMembers(Set<int> leaders) async {
  final listed = await Process.run('ps', const ['-A', '-o', 'pid=,pgid=']);
  return {
    for (final row in _rows('${listed.stdout}'))
      if (leaders.contains(row.$2)) row.$1,
  };
}

/// Every live pid reachable from a pid in [leaders] through the parent chain,
/// the leaders themselves included.
///
/// A leader that has already exited is absent from the listing and still
/// carried, because the processes it started keep naming it as their parent.
Future<Set<int>> _jobMembers(Set<int> leaders) async {
  final listed = await Process.run('powershell', const [
    '-NoProfile',
    '-NonInteractive',
    '-Command',
    r'Get-CimInstance Win32_Process | ForEach-Object '
        r"{ ($_.ProcessId, $_.ParentProcessId) -join ' ' }",
  ]);
  final rows = _rows('${listed.stdout}').toList();
  final members = <int>{};
  for (var admitted = true; admitted;) {
    admitted = false;
    for (final row in rows) {
      if (members.contains(row.$1)) continue;
      if (leaders.contains(row.$1) ||
          leaders.contains(row.$2) ||
          members.contains(row.$2)) {
        members.add(row.$1);
        admitted = true;
      }
    }
  }
  return members;
}

/// The two integer columns of every line of [listing] that has exactly two.
Iterable<(int, int)> _rows(String listing) sync* {
  for (final line in const LineSplitter().convert(listing)) {
    final columns = line.trim().split(RegExp(r'\s+'));
    if (columns.length != 2) continue;
    final first = int.tryParse(columns.first);
    final second = int.tryParse(columns.last);
    if (first != null && second != null) yield (first, second);
  }
}
