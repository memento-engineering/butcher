---
status: accepted
date: 2026-08-21
decision-makers: []
register:
  spec: 1
  slug: process-interlock
  surfaces:
    - "packages/butcher_process/lib/src/process_interlock.dart"
    - "packages/butcher_process/lib/src/posix_interlock.dart"
    - "packages/butcher_process/lib/src/windows_interlock.dart"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
  legacy-id: "0022"
---
# 0022: Process interlock

- Status: accepted

## Context

- A timed-out suite has to die with everything it started. butcher's own suite
  starts nested `butcher` runs, which start suites of their own, so an escapee is
  not idle: it keeps classifying mutants and spawning children.
- Hunting the tree from a process listing fails in the case that matters. Three
  self-runs leaked 2, then 69, then 127 processes across 24 trees, the last of
  them still spawning two and a half hours after the final timeout
  ([../plans/self-run-performance.md](../plans/self-run-performance.md)).
- Every listing-based kill shares the same defects: the helper that lists
  processes can fail or lag exactly when a loaded machine is hunting a hung
  suite, an empty answer is indistinguishable from "nothing to kill", and a
  process spawned between the listing and the kill is never seen.
- Windows job objects and POSIX process groups are the OS facilities for
  exactly this. Dart exposes neither directly, but `dart:ffi` reaches the
  first and a shim reaches the second.

## Decision

- The interlock owns the spawn. It starts the suite itself, so the started
  process is a kill boundary from the moment it exists, and there is no window
  in which a suite is running outside one.
- Owning the spawn is forced, not stylistic: post-start admission is
  impossible on POSIX, because `setpgid` refuses once the child has called
  `exec`. The implementation binds no such symbol and offers no `admit` verb
  on either platform.
- Windows: a job object created before the suite starts. Membership is
  inherited there — a job is a Windows kernel object that every descendant
  carries, including a process that detaches from its parent — and a timeout
  calls `TerminateJobObject`: one call, no listing, nothing to race.
- POSIX: a process group. The suite is started through a shim that puts
  itself into a new group and then execs the rest of its argument vector in
  place, so the pid the start returns leads its own group and the exit code,
  the working directory and both output pipes pass through untouched. The
  shim ladder is `setsid`, then `perl` with a two-line `setpgrp` program;
  `setsid` is absent from macOS and from minimal images, perl is present on
  both. A timeout signals the whole group in one call.
- `dart:ffi` binds the four `kernel32` entry points needed
  (`CreateJobObjectW`, `OpenProcess`, `AssignProcessToJobObject`,
  `TerminateJobObject`). No package dependency is added.
- Where no shim resolves, the interlock kills the started pid alone and says
  so in its diagnostics. It never falls back to listing processes: the process
  snapshot, its five-pass sweep and its descendant walker are deleted.

## Consequences

- The kill stops depending on anything that can fail under load, on both
  platforms.
- There is no admission window at all: nothing the suite starts can predate
  the boundary, because the boundary predates the suite.
- Nested runs work: job objects nest since Windows 8, so a `butcher` inside a
  suite inside a job creates its own; a nested run on POSIX leads a group of
  its own the same way.
- The interlock is not a lifetime guarantee: butcher killed outright still leaves
  its suites running, since the job is not set to die with its handle. Adding
  `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` would fix that, and needs an allocator,
  which means a dependency.
- One POSIX escape is honest and documented: a descendant that creates a
  session of its own leaves the group and survives the kill.
  [`packages/butcher_process/test/posix_interlock_test.dart`](../../packages/butcher_process/test/posix_interlock_test.dart)
  pins it deterministically with a perl descendant that calls `setsid`. No
  escape rate is recorded, because none was reproduced. It is not a new hole
  either: such a process is reparented to pid 1, which destroys the parent
  link, so it was equally unreachable from the process-listing sweep it
  replaces.
- The contract is the process GROUP, not the session. Whether the started
  process also leads a new session differs between the ladder's rungs and is
  deliberately unspecified: both output streams are always piped, so the
  process can never observe a terminal.

## Rejected

- Retrying and verifying the sweep: cheaper, but still best-effort against a
  runner that spawns constantly, and still silent when the listing fails.
- `taskkill /T`: the same race, plus a process spawn per kill.
- Admitting the pid after `Process.start`: it cannot be done on POSIX, and a
  Windows-only admission seam would model a boundary the tool does not have.
