# Spike: shadow-copy mechanics

Goal: prove the MVP isolation model works on Windows before building on it.
Timebox: ~30 min. Throwaway code; only findings are kept.

## Questions to answer

1. Can `dart test` run against a mutated copy of `lib/` without touching the
   working tree?
   - Option A: generated `package_config.json` pointing the package root at a
     temp copy of `lib/`.
   - Option B (fallback, known to work): copy the entire project to a temp dir
     and run tests there.
2. Can a hung `dart test` process tree be killed reliably on Windows?
3. Does test output/exit code behave the same under the chosen option?

## Steps

- Copy `sandbox/lib/` to a temp dir; flip one operator in the copy.
- Try option A; if resolution fails, fall back to option B.
- Run `dart test` via `Platform.resolvedExecutable`; confirm the mutant is
  detected while `sandbox/` stays clean.
- Start a test with an infinite loop; kill the process tree; confirm no
  orphans remain.

## Success criteria

- One option confirmed: mutant killed, working tree untouched.
- Process-tree kill confirmed without orphaned `dart` processes.
- Decision recorded here: chosen option + rationale.
