# butcher_report

The Stryker mutation-report schema, split out of the [butcher](../butcher)
mutation engine so a consumer can read or write the report without taking the
engine.

Stryker's JSON report is butcher's primary output format, which makes its
shape a contract rather than an implementation detail: a dashboard or a CI
gate should be able to parse it without depending on the tool that produced
it.

The typed models land here with the report work; today the package publishes
its name and nothing else.

## License

MIT, derived from the upstream `radioactive_dart` package — see
[LICENSE](LICENSE).
