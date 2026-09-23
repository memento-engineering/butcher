import 'dart:ffi';
import 'dart:io';

import 'process_interlock.dart';

/// One rung of the shim ladder: an executable that puts itself into a new
/// process group and then execs the rest of its argument vector in place.
///
/// Execing in place is what makes the rung usable: the pid returned by the
/// start is the group leader, and the exit code, the working directory and
/// both output pipes pass through untouched.
typedef ShimRung = ({String executable, List<String> arguments});

/// The program handed to the perl rung.
///
/// `setpgrp` conventions differ between perl builds, so success is confirmed
/// by reading the group back rather than by the return value. Either failure
/// dies loudly instead of exec'ing outside a group of its own.
const _perlShim = r'''
setpgrp(0, 0);
die "butcher_process: setpgrp failed: $!\n" unless getpgrp(0) == $$;
exec { $ARGV[0] } @ARGV;
die "butcher_process: exec failed: $!\n";
''';

/// The rungs [PosixInterlock] tries, in order, to find a shim.
///
/// `setsid` forks only when it is already a process group leader, which a
/// child of this process can never be, so it execs in place. It is absent
/// from macOS and from minimal images; perl is present on both and costs a
/// few milliseconds per start, with no extra process, no extra pipe and
/// nothing to reap.
const defaultShimLadder = <ShimRung>[
  (executable: '/usr/bin/setsid', arguments: <String>[]),
  (executable: '/bin/setsid', arguments: <String>[]),
  (executable: '/usr/bin/perl', arguments: <String>['-e', _perlShim]),
];

/// [ProcessInterlock] over a POSIX process group.
///
/// The process is started through a shim that puts itself into a new process
/// group before exec'ing, so the started pid leads its own group and
/// everything it spawns inherits that group. [terminate] then signals the
/// whole group in one call, with nothing to list and nothing to race.
///
/// The contract is the process GROUP, not the session. Whether the started
/// process also leads a new session differs between the ladder's rungs and is
/// deliberately unspecified, because nothing depends on it: stdout and stderr
/// are always piped, so the process can never observe a terminal, and neither
/// a new group nor a new session receives the terminal's interrupt signal
/// either way. A consumer that wants to die tidily on an interrupt installs a
/// signal handler.
///
/// One escape is honest and documented: a descendant that creates a session of
/// its own leaves the group and survives [terminate]. That is not a
/// regression. Such a process is reparented to pid 1, which destroys the
/// parent link, so it was equally unreachable from the process-listing sweep
/// this replaces.
final class PosixInterlock implements ProcessInterlock {
  /// Resolves the shim once, over [ladder], probing each rung with [probe] and
  /// reporting a failure to resolve through [diagnostics].
  PosixInterlock({
    List<ShimRung> ladder = defaultShimLadder,
    bool Function(String executable)? probe,
    void Function(String message)? diagnostics,
  }) : _shim = _resolve(
         ladder,
         probe ?? _exists,
         diagnostics ?? _writeToStderr,
       );

  /// The rung that resolved, or `null` when none did.
  final ShimRung? _shim;

  static bool _exists(String executable) => File(executable).existsSync();

  static void _writeToStderr(String message) => stderr.writeln(message);

  static ShimRung? _resolve(
    List<ShimRung> ladder,
    bool Function(String executable) probe,
    void Function(String message) diagnostics,
  ) {
    for (final rung in ladder) {
      if (probe(rung.executable)) return rung;
    }
    final tried = ladder.isEmpty
        ? 'an empty ladder'
        : ladder.map((rung) => rung.executable).join(', ');
    diagnostics(
      'butcher_process: no process-group shim resolved (tried $tried); '
      'a terminated process will be killed alone and its descendants will '
      'survive. Install setsid or perl to close the hole.',
    );
    return null;
  }

  /// The single FFI binding in this package, resolved through the process's
  /// own dynamic library handle so it reaches libc without naming a library
  /// file. `setpgid` is deliberately not bound: called from the parent after a
  /// start it always fails, because the VM blocks until the child has exec'd.
  static final _getpgid = DynamicLibrary.process()
      .lookupFunction<Int32 Function(Int32), int Function(int)>('getpgid');

  /// The process group [pid] belongs to, or `-1` when it cannot be read.
  static int processGroupOf(int pid) => _getpgid(pid);

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    final shim = _shim;
    return Process.start(
      shim?.executable ?? executable,
      shim == null ? arguments : [...shim.arguments, executable, ...arguments],
      workingDirectory: workingDirectory,
    );
  }

  /// Kills the group [process] leads, or [process] alone when it does not lead
  /// one, then awaits its exit code.
  ///
  /// The second branch needs no listing to be airtight: the only moment the
  /// pid and its group differ is between the shim's own exec and its group
  /// call, and in that window the shim has not exec'd anything yet and has no
  /// descendants.
  @override
  Future<void> terminate(Process process) async {
    final pid = process.pid;
    final group = processGroupOf(pid) == pid ? -pid : pid;
    Process.killPid(group, ProcessSignal.sigkill);
    await process.exitCode;
  }

  /// Holds nothing; the group dies with its members.
  @override
  void dispose() {}
}
