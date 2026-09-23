import 'dart:ffi';
import 'dart:io';

import 'process_interlock.dart';

/// [ProcessInterlock] over a Windows job object, so the whole tree dies in one
/// call instead of being hunted for.
///
/// Nothing is listed and nothing races: a process admitted to a job carries
/// its membership to every process it starts, and `TerminateJobObject` kills
/// them together.
final class WindowsInterlock implements ProcessInterlock {
  /// Creates the job every process started here is admitted to.
  WindowsInterlock() : _job = _createJobObject?.call(nullptr, nullptr) ?? 0;

  /// Handle of the job every admitted process belongs to, or `0` when the
  /// platform has no job objects and on the rare failure to create one.
  final int _job;

  bool _disposed = false;

  /// Rights needed to put a process into a job and to kill it there.
  static const _processSetQuota = 0x0100;
  static const _processTerminate = 0x0001;

  static final DynamicLibrary? _kernel32 = Platform.isWindows
      ? DynamicLibrary.open('kernel32.dll')
      : null;

  static final _createJobObject = _kernel32
      ?.lookupFunction<
        IntPtr Function(Pointer<Void>, Pointer<Void>),
        int Function(Pointer<Void>, Pointer<Void>)
      >('CreateJobObjectW');

  static final _openProcess = _kernel32
      ?.lookupFunction<
        IntPtr Function(Uint32, Int32, Uint32),
        int Function(int, int, int)
      >('OpenProcess');

  static final _assignProcessToJobObject = _kernel32
      ?.lookupFunction<Int32 Function(IntPtr, IntPtr), int Function(int, int)>(
        'AssignProcessToJobObject',
      );

  static final _terminateJobObject = _kernel32
      ?.lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
        'TerminateJobObject',
      );

  static final _closeHandle = _kernel32
      ?.lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'CloseHandle',
      );

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    // Admitted before the caller can drain a stream, and so before the
    // process can start anything of its own: what it spawns afterwards joins
    // the job and dies with it.
    admit(process.pid);
    return process;
  }

  /// Puts the process [pid] into the job. Everything it starts afterwards
  /// joins with it; anything it started before does not, so admit a process as
  /// soon as it exists.
  bool admit(int pid) {
    if (_job == 0) return false;
    final process = _openProcess!(_processSetQuota | _processTerminate, 0, pid);
    if (process == 0) return false;
    final assigned = _assignProcessToJobObject!(_job, process);
    _closeHandle!(process);
    return assigned != 0;
  }

  @override
  Future<void> terminate(Process process) async {
    if (_job == 0) {
      process.kill(ProcessSignal.sigkill);
    } else {
      _terminateJobObject!(_job, 1);
    }
    await process.exitCode;
  }

  /// Releases the job handle; processes still in it keep running.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_job != 0) _closeHandle!(_job);
  }
}
