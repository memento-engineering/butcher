# 4. Stale-lock handling

- Status: pending
- Decision: [0018](../../decisions/2026-08-15-run-workspace-lifecycle.md)
- Needs: [config-schema.md](config-schema.md) for the `non-interactive` name

Goal: a lock left by a crashed run stops being a dead end, and CI never waits
on a prompt.

## Today

`RunWorkspace.acquire` creates the lock file exclusively and aborts on
conflict, telling the user to delete it by hand. The file is empty, so nothing
can tell a held lock from an abandoned one.

## Questions to answer

1. What does the lock carry? Candidate: run id, pid, process start time, host,
   started-at. Start time is what defeats pid reuse.
2. How is liveness checked per platform without spawning a process per check?
   Windows has no signals, so `Process.killPid` with signal 0 is not the
   portable answer it is elsewhere. This is the spike.
3. `RAD_TEMP` can point at a shared location. When the recorded host is not
   this one, liveness is unknowable — prompt, or abort and say why?
4. What counts as interactive? `stdin.hasTerminal` is the obvious test; decide
   whether a missing terminal already implies `--non-interactive`.
5. Does taking a lock have to clean the previous run's containments, or does
   the existing startup `clean()` already cover it?

## Steps

- Write the owner record into the lock file at acquisition.
- On conflict: report the owner, decide alive or stale, then prompt or abort.
- Add `--non-interactive`; a non-terminal stdin behaves the same.

## Success criteria

- A lock whose owner is alive is never taken, prompt or no prompt.
- A lock whose owner is provably gone is taken after one confirmation.
- Regression coverage: two concurrent runs, a crashed run, and a stale record
  whose pid now belongs to something else.
- The abort message names the owning run, not just the path.

## Seams for later

- v1.0 dogfooding runs `rad` on a schedule against a machine that may hold a
  stale lock. The workflow uses `--non-interactive` and a serialized
  concurrency group.
- rad's own e2e suite spawns rad. Nested runs get their own `RAD_TEMP`, and
  the owner record must never let one be mistaken for a stale parent.

## Result

Pending.
