# butcher_process

Process-tree lifetime and kill primitives, split out of the
[butcher](../butcher) mutation engine so a consumer can take the process
abstraction without taking the engine.

The engine spawns real test suites, and those suites spawn their own children.
Bounding such a run means ending a whole tree, not one process, and doing it
the same way on every platform butcher runs on. That is what this package
owns.

The abstraction lands here with the process-control work; today the package
publishes its name and nothing else.

## License

MIT, derived from the upstream `radioactive_dart` package — see
[LICENSE](LICENSE).
