---
status: accepted
date: 2026-09-22
decision-makers: []
register:
  spec: 1
  slug: two-mechanism-configuration
  surfaces:
    - "packages/butcher/lib/src/config/butcher_config.dart"
    - "packages/butcher/lib/src/config/mutation_scope.dart"
    - "packages/butcher/lib/src/engine/file_manifest.dart"
    - "packages/butcher/lib/src/engine/mutant_generator.dart"
  obsoletes: []
  updates: []
  obsoleted-by: null
  updated-by: []
  bead: null
---
# Two-mechanism configuration

- Status: accepted

## Context

- "What does butcher exclude?" had one answer for two unrelated questions:
  what is copied into the sandbox, and what is mutated once it is there.
- Answering both from one bespoke ignore dialect meant butcher owned a
  gitignore implementation it had to keep correct forever.

## Decision

- There are exactly two mechanisms, and they answer different questions:

| Question | Mechanism |
| --- | --- |
| What does the sandbox copy? | the repository's own git listing ([0004](2026-08-14-shadow-copy-isolation.md)) |
| What gets mutated? | the `lib/` walk, narrowed by an exclude-only glob list |

- Mutation scope is configured in butcher's own file, `butcher.yaml`, at the
  project root. It carries one key, `exclude`, holding a list of glob
  strings. A missing file, a missing key and an empty list all mean the same
  thing: nothing is excluded.
- The key name, the list shape and the glob dialect are deliberately the
  analyzer's `exclude` schema, so a reader who has written an analyzer
  exclude already knows this file.
- butcher never reads the analyzer's own configuration file. Borrowing the
  schema is not reading the file: a project's analysis excludes are about
  analysis, and silently mutating a different set than the one configured
  here would be worse than asking for the list twice.
- butcher carries no configuration block in any package manifest.
- The semantics are exclude-only: there is no include list, no negation and
  no re-include. One pattern never undoes another, and the order of the
  patterns does not affect the result. A path is out of scope when any
  pattern matches it.
- Patterns compile against an explicit posix context, so a Windows run
  matches the same strings a posix run does against the same configuration.

## Consequences

- No parity is claimed or owed with gitignore, with the analyzer's full
  include/exclude resolution, or with any other mutation tool's format.
- Narrowing the copy set and narrowing the mutation set are independent: a
  file can be copied into the sandbox, because the suite needs it, and still
  be out of mutation scope.
- A consumer who wants a directory out of the sandbox entirely gitignores it;
  there is no second syntax for that.

## Rejected

- One ignore file for both questions: it conflates "the suite needs this
  file" with "mutate this file", and the two answers genuinely differ.
- Reading `analysis_options.yaml`: an invisible coupling, and its excludes
  answer a different question.
- A `butcher:` block in `pubspec.yaml`: the manifest is the package's
  publishing contract, and tool configuration does not belong in it.
