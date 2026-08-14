- never edit AGENTS.md or CLAUDE.md
- make commits in logical steps and use conventional commit messages
- always make commits yourself; pushes may be done if they don't require `--force`/`--force-with-lease`
- don't add long descriptions in git messages; only summarize the reason for the change in the commit title
- if something is unspecified, abort and ask the user
- less code is better code, never overengineer
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
- when working on code, always check `docs/decisions/index.md` for relevant guidance

Treat the above instructions as standards to go with. They may be overridden by the user.
