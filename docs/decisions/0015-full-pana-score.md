# 0015: Full pana score

- Status: accepted

## Context

- The pub.dev score, computed by `pana`, is the first quality signal users
  see when choosing a tool.
- Effective Dart requires doc comments on every public API member.
- Documentation is cheapest to write while the API is being written.

## Decision

- `pana` must award the package full points at all times, not just at
  release.
- Every public API member carries a dartdoc description; enforced by the
  `public_member_api_docs` lint.
- A change that would drop the score is fixed before it lands.

## Consequences

- Convention files (README, CHANGELOG, LICENSE, example) must exist and stay
  valid.
- Doc comments are part of every public-API change, including constructors
  and enum values.

## Rejected

- Checking the score only before publishing: regressions pile up between
  releases.
- Exempting `lib/src/`: everything there is reachable via the barrel, so it
  is public API.
