/// The mutation-testing report schema as Dart types, with no file or network
/// I/O.
///
/// The schema is the Stryker `mutation-testing-report-schema`, draft-07,
/// titled `MutationTestResult`. Reading and writing the bytes is the caller's
/// job, which is what lets a dashboard or a CI gate depend on this package
/// without depending on the mutation engine.
library;

export 'src/location.dart';
export 'src/mutant_status.dart';
