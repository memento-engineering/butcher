# Changelog

## 0.1.0

- Initial release: the Stryker `MutationTestResult` schema as Dart types, with
  parsing from a JSON string or an already-decoded map, emission back to a map,
  and no file or network I/O.
- Every required field is enforced on parse with a format exception naming it;
  absent optional fields are omitted from the emitted map rather than written
  as null.
- Every public type compares by value, hand-written, with no code-generation
  dependency.
- Published to pub.dev on 2026-09-23.
