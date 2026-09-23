# Changelog

## 0.1.0

- Initial release: butcher's process-tree lifetime and kill primitives.
- `ProcessInterlock` owns the spawn on both platforms, so a kill reaches the
  whole tree in one call instead of hunting it through a process listing.
- `SupervisedProcess` and `terminateAllSupervisedProcesses` own the lifetime of
  a started tree.
- `hostProcessCount` reports the host's live process count as a diagnostic.
- Published to pub.dev on 2026-09-23.
