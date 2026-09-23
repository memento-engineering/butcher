/// The `TestFile` and `TestDefinition` types of the report schema.
library;

import 'equality.dart';
import 'json_object.dart';
import 'location.dart';

/// One test file's entry in a report's `testFiles` dictionary.
///
/// The key this entry sits under is a file path or a class name, whichever the
/// producer correlates tests by. Only [tests] is required.
final class TestFile {
  /// Creates the entry for a file holding [tests].
  const TestFile({required this.tests, this.source});

  /// The schema fields a test file must carry.
  static const requiredJsonFields = <String>{'tests'};

  /// The schema fields a test file may carry.
  static const optionalJsonFields = <String>{'source'};

  /// Reads a test file from decoded JSON.
  static TestFile fromJson(Object? json) {
    final object = JsonObject.read(json, 'TestFile');
    return TestFile(
      tests: object.requiredList('tests', TestDefinition.fromJson),
      source: object.optionalString('source'),
    );
  }

  /// The tests this file defines.
  final List<TestDefinition> tests;

  /// The full source of the test file, for display in a report.
  final String? source;

  /// Writes this test file as decoded JSON, omitting an absent source.
  Map<String, Object?> toJson() => <String, Object?>{
    'tests': <Object?>[for (final test in tests) test.toJson()],
    'source': ?source,
  };

  @override
  bool operator ==(Object other) =>
      other is TestFile &&
      deepEquals(other.tests, tests) &&
      other.source == source;

  @override
  int get hashCode => Object.hash(deepHash(tests), source);

  @override
  String toString() => 'TestFile(tests: ${tests.length})';
}

/// One test inside a test file.
///
/// [id] correlates the test with a mutant's `coveredBy` and `killedBy` lists,
/// so it has to be unique across the whole report, not just within its file.
final class TestDefinition {
  /// Creates the test [id] named [name].
  const TestDefinition({required this.id, required this.name, this.location});

  /// The schema fields a test definition must carry.
  static const requiredJsonFields = <String>{'id', 'name'};

  /// The schema fields a test definition may carry.
  static const optionalJsonFields = <String>{'location'};

  /// Reads a test definition from decoded JSON.
  static TestDefinition fromJson(Object? json) {
    final object = JsonObject.read(json, 'TestDefinition');
    return TestDefinition(
      id: object.requiredString('id'),
      name: object.requiredString('name'),
      location: object.optionalObject('location', OpenEndLocation.fromJson),
    );
  }

  /// The id a mutant's coverage lists refer to this test by.
  final String id;

  /// The test's display name.
  final String name;

  /// Where the test sits in its file, whose end the producer may omit.
  final OpenEndLocation? location;

  /// Writes this test as decoded JSON, omitting an absent location.
  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    if (location case final location?) 'location': location.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is TestDefinition &&
      other.id == id &&
      other.name == name &&
      other.location == location;

  @override
  int get hashCode => Object.hash(id, name, location);

  @override
  String toString() => 'TestDefinition(id: $id, name: $name)';
}
