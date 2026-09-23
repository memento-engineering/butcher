/// The `MutationTestResult` root type of the mutation-testing report schema.
library;

import 'equality.dart';
import 'file_result.dart';
import 'json_object.dart';
import 'run_metadata.dart';
import 'test_file.dart';
import 'thresholds.dart';

/// A whole mutation-testing report.
///
/// Three fields are required — [schemaVersion], [thresholds] and [files] — and
/// six are optional. An absent optional is omitted from [toJson] rather than
/// written as null.
///
/// [schemaVersion] is checked against the schema's own pattern on parse, so a
/// document declaring a major version this schema does not cover is rejected
/// at the door rather than half-read.
final class MutationTestResult {
  /// Creates a report.
  const MutationTestResult({
    required this.schemaVersion,
    required this.thresholds,
    required this.files,
    this.config,
    this.testFiles,
    this.projectRoot,
    this.performance,
    this.framework,
    this.system,
  });

  /// The schema fields a report must carry.
  static const requiredJsonFields = <String>{
    'schemaVersion',
    'thresholds',
    'files',
  };

  /// The schema fields a report may carry.
  static const optionalJsonFields = <String>{
    'config',
    'testFiles',
    'projectRoot',
    'performance',
    'framework',
    'system',
  };

  /// The pattern the schema constrains `schemaVersion` with.
  ///
  /// Major version 1 or 2, then up to two more dotted parts, each either zero
  /// or a number with no leading zero: `1`, `2.0` and `2.0.0` all match.
  static const schemaVersionPattern = r'^([1-2])(\.(([1-9]\d*)|0)){0,2}$';

  /// Reads a report from decoded JSON.
  ///
  /// Throws a [FormatException] naming the first violated requirement.
  static MutationTestResult fromJson(Object? json) {
    final object = JsonObject.read(json, 'MutationTestResult');
    final version = object.requiredString('schemaVersion');
    if (!RegExp(schemaVersionPattern).hasMatch(version)) {
      throw FormatException(
        'MutationTestResult field "schemaVersion" must match '
        '$schemaVersionPattern, but was "$version".',
      );
    }
    return MutationTestResult(
      schemaVersion: version,
      thresholds: object.requiredObject('thresholds', Thresholds.fromJson),
      files: object.requiredDictionary('files', FileResult.fromJson),
      config: object.optionalFreeFormObject('config'),
      testFiles: object.optionalDictionary('testFiles', TestFile.fromJson),
      projectRoot: object.optionalString('projectRoot'),
      performance: object.optionalObject(
        'performance',
        PerformanceStatistics.fromJson,
      ),
      framework: object.optionalObject(
        'framework',
        FrameworkInformation.fromJson,
      ),
      system: object.optionalObject('system', SystemInformation.fromJson),
    );
  }

  /// The report's schema version, used for compatibility.
  final String schemaVersion;

  /// The mutation-score bands this report is graded against.
  final Thresholds thresholds;

  /// Every mutated file, keyed by its path relative to the project root.
  final Map<String, FileResult> files;

  /// The producer's own configuration, which the schema leaves free-form.
  final Map<String, Object?>? config;

  /// Every test file, keyed by path or class name.
  final Map<String, TestFile>? testFiles;

  /// The project root the file keys are relative to.
  final String? projectRoot;

  /// How long each phase of the run took.
  final PerformanceStatistics? performance;

  /// Which framework produced the report.
  final FrameworkInformation? framework;

  /// The machine the run happened on.
  final SystemInformation? system;

  /// Writes this report as decoded JSON, omitting every absent optional.
  ///
  /// The caller encodes the result; this package does no I/O.
  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'thresholds': thresholds.toJson(),
    'files': <String, Object?>{
      for (final entry in files.entries) entry.key: entry.value.toJson(),
    },
    'config': ?config,
    if (testFiles case final testFiles?)
      'testFiles': <String, Object?>{
        for (final entry in testFiles.entries) entry.key: entry.value.toJson(),
      },
    'projectRoot': ?projectRoot,
    if (performance case final performance?)
      'performance': performance.toJson(),
    if (framework case final framework?) 'framework': framework.toJson(),
    if (system case final system?) 'system': system.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is MutationTestResult &&
      other.schemaVersion == schemaVersion &&
      other.thresholds == thresholds &&
      deepEquals(other.files, files) &&
      deepEquals(other.config, config) &&
      deepEquals(other.testFiles, testFiles) &&
      other.projectRoot == projectRoot &&
      other.performance == performance &&
      other.framework == framework &&
      other.system == system;

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    thresholds,
    deepHash(files),
    deepHash(config),
    deepHash(testFiles),
    projectRoot,
    performance,
    framework,
    system,
  );

  @override
  String toString() =>
      'MutationTestResult(schemaVersion: $schemaVersion, '
      'files: ${files.length}, thresholds: $thresholds)';
}
