# Process-group verification

Receipts taken before the process-table sweep was deleted from the test runner.
Every measurement behind the POSIX mechanism in
[0022](../decisions/2026-08-21-process-interlock.md) had been taken on macOS, and
the sweep was the only thing proving descendants die off Windows. The org CI
repository does not exist yet, so the second platform was a local Linux
container (Apple containers; Docker is retired).

## Hosts

| | macOS host | Linux container |
|---|---|---|
| Kernel | Darwin 26.6.2, arm64 | Linux 6.18.5, aarch64 |
| Dart | 3.12.2 stable | 3.13.3 stable |
| Image | - | `dart:3.13.3` plus `procps`, `perl` |
| Shim rung resolved | `/usr/bin/perl` | `/usr/bin/setsid` |

Both rungs of the shim ladder are therefore covered: macOS has no `setsid` and
falls to perl, Linux takes the first rung.

## `butcher_process`, before the deletion

| | macOS host | Linux container |
|---|---|---|
| `dart analyze` | no issues | no issues |
| `dart test` | 16 passed | 16 passed |

The group-kill proofs pass on both: `terminate kills the grandchildren with the
child`, `the started process leads its own process group`, `a deadline returns
null and leaves nothing alive`, and `terminate-all reaps independently started
processes`.

