import 'dart:ffi';
import 'dart:io';

/// Windows job object holding one suite and everything it spawns, so the
/// whole tree dies in one call instead of being hunted for (ADR 0022).
///
/// Nothing is listed and nothing races: a process admitted to a job carries
/// its membership to every process it starts, and `TerminateJobObject` kills
/// them together. Elsewhere the caller falls back to a process snapshot.
final class ProcessInterlock {
  ProcessInterlock._(this._job);

  /// Handle of the job every admitted process belongs to.
  final int _job;

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

  /// Creates an interlock, or `null` where the platform has no job objects
  /// and on the rare failure to create one; the caller then falls back.
  static ProcessInterlock? create() {
    final create = _createJobObject;
    if (create == null) return null;
    final job = create(nullptr, nullptr);
    return job == 0 ? null : ProcessInterlock._(job);
  }

  /// Puts the process [pid] into the job. Everything it starts afterwards
  /// joins with it; anything it started before does not, so admit a suite as
  /// soon as it exists.
  bool admit(int pid) {
    final process = _openProcess!(_processSetQuota | _processTerminate, 0, pid);
    if (process == 0) return false;
    final assigned = _assignProcessToJobObject!(_job, process);
    _closeHandle!(process);
    return assigned != 0;
  }

  /// Kills every process in the job.
  void terminate() => _terminateJobObject!(_job, 1);

  /// Releases the job handle; processes still in it keep running.
  void dispose() => _closeHandle!(_job);
}
