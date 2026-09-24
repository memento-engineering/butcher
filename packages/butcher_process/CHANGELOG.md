# Changelog

## 0.1.1-dev.2

- `liveDescendants` reports the live pids inside the kill boundaries a run
  started: the process groups it leads on POSIX, the job membership it started
  on Windows. Read-only accounting, so a consumer can prove a run leaked
  nothing without counting the whole host.
- `hostProcessCount` is unchanged and is documented as a diagnostic only; it
  cannot tell a run's descendants from anything else the machine spawns.

## 0.1.1-dev.1

- Automation proof: first tag-driven publish. No library change.

## 0.1.0

- Initial release: butcher's process-tree lifetime and kill primitives.
- `ProcessInterlock` owns the spawn on both platforms, so a kill reaches the
  whole tree in one call instead of hunting it through a process listing.
- `SupervisedProcess` and `terminateAllSupervisedProcesses` own the lifetime of
  a started tree.
- `hostProcessCount` reports the host's live process count as a diagnostic.
- Published to pub.dev on 2026-09-23.
