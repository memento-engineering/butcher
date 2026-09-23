# butcher_process

Process-tree lifetime and kill primitives, split out of the
[butcher](../butcher) mutation engine so a consumer can take the process
abstraction without taking the engine.

The engine spawns real test suites, and those suites spawn their own children.
Bounding such a run means ending a whole tree, not one process, and doing it
the same way on every platform butcher runs on. That is what this package
owns.

## What it gives you

| Surface | What it does |
| --- | --- |
| `ProcessInterlock` | Owns the spawn, so the started process is a kill boundary; a job object on Windows, a process group on POSIX. |
| `SupervisedProcess` | One process tree with one owner: streams, a deadline, an idempotent kill. |
| `terminateAllSupervisedProcesses` | Reaps every live tree, so a signal handler needs no handle on a worker pool. |
| `hostProcessCount` | A diagnostic count of live processes on the host, never a kill path. |

```dart
final process = await SupervisedProcess.start('dart', ['test']);
final code = await process.wait(deadline: const Duration(minutes: 10));
if (code == null) print('the tree was killed on its deadline');
```

## Limits

- A descendant that creates a session of its own leaves the group and survives
  the kill. Such a process is reparented to pid 1, so it is unreachable from a
  process listing too.
- On POSIX the group is entered by an exec-in-place shim: `setsid` where it
  exists, otherwise `perl`. Without either, the kill reaches only the started
  process and says so once, loudly.

## License

MIT, derived from the upstream `radioactive_dart` package — see
[LICENSE](LICENSE).
