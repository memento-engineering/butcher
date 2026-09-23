- never edit AGENTS.md or CLAUDE.md
- make commits in logical steps and use conventional commit messages
- always make commits yourself; pushes may only be done on non-`main` branches and if they don't require `--force`/`--force-with-lease`
- don't add long descriptions in git messages; only summarize the reason for the change in the commit title
- if something is unspecified, abort and ask the user
- less code is better code; if you can remove code or simplify, do so
- never overengineer; tech debt should be avoided, but not at the cost of a significantly more complex solution
- always try to find the minimal amount of changes necessary to complete a task; avoid rewriting whole files
- keep existing documentation updated when making changes
- documentation should consist of short sentences, lists, mermaid diagrams and tables; never long paragraphs
- documents should be kept as short as possible; prefer splitting a long document into multiple smaller ones with an `index.md` file
- keep the architecture clean with small classes, one file per class
- use well-understood design patterns where appropriate
- follow Dart best practices, however, don't overdo it just to stick to gospel
- avoid letting branches grow indefinitely; warn the user if the amount of changes in a branch gets "large"
- long-standing decisions for the project should be recorded in `docs/decisions/` as ADR documents
- when looking for guidance, check `docs/index.md`
- when working on code, always check `docs/decisions/views/index.md` for relevant guidance
- always differentiate between docs for maintainers and docs for users; never leak one into the other (for example, users don't care about ADRs)
- every _user visible_ change should get an entry in the CHANGELOG.md; internal changes don't get one
- the pubspec.yaml on main always contains the in-development version
- upon release, the version in pubspec.yaml should be added on top of the unreleased changes in CHANGELOG.md and then bumped according to SemVer
- avoid adding comments in code; only add them where they actually add value, not to restate what the code already describes

Treat the above instructions as standards to go with. They may be overridden by the user.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->
