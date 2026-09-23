import 'dart:convert';
import 'dart:io';

import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

/// The checked-in copy of the published schema, the authority for this suite.
///
/// Every other test in this package is written from the same understanding the
/// models were, so it could agree with them and still be wrong. This one reads
/// the schema document itself.
final _schema =
    jsonDecode(
          File(
            'test/fixtures/mutation-testing-report-schema.json',
          ).readAsStringSync(),
        )
        as Map<String, Object?>;

/// Walks [path] from the schema root, resolving any `$ref` it passes through.
Map<String, Object?> _at(List<String> path) {
  var node = _schema;
  for (final step in path) {
    final next = node[step];
    if (next is! Map<String, Object?>) {
      throw StateError('The schema has no "$step" under ${path.join('/')}.');
    }
    node = _resolve(next);
  }
  return node;
}

Map<String, Object?> _resolve(Map<String, Object?> node) {
  final reference = node[r'$ref'];
  if (reference is! String) return node;
  final pointer = reference.replaceFirst('#/', '').split('/');
  var target = _schema;
  for (final step in pointer) {
    target = target[step]! as Map<String, Object?>;
  }
  return target;
}

Set<String> _required(Map<String, Object?> node) => <String>{
  ...(node['required'] as List<Object?>? ?? <Object?>[]).cast(),
};

Set<String> _properties(Map<String, Object?> node) => <String>{
  ...(node['properties']! as Map<String, Object?>).keys,
};

/// Every type this package models, against where the schema declares it.
final _modelled = <String, (List<String>, Set<String>, Set<String>)>{
  'MutationTestResult': (
    <String>[],
    MutationTestResult.requiredJsonFields,
    MutationTestResult.optionalJsonFields,
  ),
  'FileResult': (
    <String>['properties', 'files', 'additionalProperties'],
    FileResult.requiredJsonFields,
    FileResult.optionalJsonFields,
  ),
  'MutantResult': (
    <String>[
      'properties',
      'files',
      'additionalProperties',
      'properties',
      'mutants',
      'items',
    ],
    ReportMutant.requiredJsonFields,
    ReportMutant.optionalJsonFields,
  ),
  'TestFile': (
    <String>['properties', 'testFiles', 'additionalProperties'],
    TestFile.requiredJsonFields,
    TestFile.optionalJsonFields,
  ),
  'TestDefinition': (
    <String>[
      'properties',
      'testFiles',
      'additionalProperties',
      'properties',
      'tests',
      'items',
    ],
    TestDefinition.requiredJsonFields,
    TestDefinition.optionalJsonFields,
  ),
  'Thresholds': (
    <String>['properties', 'thresholds'],
    Thresholds.requiredJsonFields,
    Thresholds.optionalJsonFields,
  ),
  'PerformanceStatistics': (
    <String>['properties', 'performance'],
    PerformanceStatistics.requiredJsonFields,
    PerformanceStatistics.optionalJsonFields,
  ),
  'FrameworkInformation': (
    <String>['properties', 'framework'],
    FrameworkInformation.requiredJsonFields,
    FrameworkInformation.optionalJsonFields,
  ),
  'BrandingInformation': (
    <String>['properties', 'framework', 'properties', 'branding'],
    BrandingInformation.requiredJsonFields,
    BrandingInformation.optionalJsonFields,
  ),
  'SystemInformation': (
    <String>['properties', 'system'],
    SystemInformation.requiredJsonFields,
    SystemInformation.optionalJsonFields,
  ),
  'OSInformation': (
    <String>['properties', 'system', 'properties', 'os'],
    OsInformation.requiredJsonFields,
    OsInformation.optionalJsonFields,
  ),
  'CpuInformation': (
    <String>['properties', 'system', 'properties', 'cpu'],
    CpuInformation.requiredJsonFields,
    CpuInformation.optionalJsonFields,
  ),
  'RamInformation': (
    <String>['properties', 'system', 'properties', 'ram'],
    RamInformation.requiredJsonFields,
    RamInformation.optionalJsonFields,
  ),
  'Position': (
    <String>['definitions', 'position'],
    Position.requiredJsonFields,
    Position.optionalJsonFields,
  ),
  'Location': (
    <String>['definitions', 'location'],
    Location.requiredJsonFields,
    Location.optionalJsonFields,
  ),
  'OpenEndLocation': (
    <String>['definitions', 'openEndLocation'],
    OpenEndLocation.requiredJsonFields,
    OpenEndLocation.optionalJsonFields,
  ),
};

void main() {
  group('the checked-in schema copy', () {
    test('is the draft-07 MutationTestResult schema', () {
      expect(_schema[r'$schema'], 'http://json-schema.org/draft-07/schema#');
      expect(_schema['title'], 'MutationTestResult');
      expect(_schema[r'$id'], 'http://stryker-mutator.io/report.schema.json');
    });

    test('declares every type this package models', () {
      for (final entry in _modelled.entries) {
        final (path, _, _) = entry.value;
        expect(
          _at(path)['title'] ?? 'MutationTestResult',
          entry.key,
          reason: '${entry.key} is not where this suite looks for it',
        );
      }
    });
  });

  group('required fields', () {
    _modelled.forEach((name, entry) {
      final (path, required, _) = entry;
      test('$name requires exactly what the schema requires', () {
        expect(
          required,
          _required(_at(path)),
          reason: 'the modelled required fields of $name diverged',
        );
      });
    });
  });

  group('modelled fields', () {
    _modelled.forEach((name, entry) {
      final (path, required, optional) = entry;
      test('$name models every field the schema declares', () {
        expect(
          <String>{...required, ...optional},
          _properties(_at(path)),
          reason: 'the modelled fields of $name diverged',
        );
        expect(
          required.intersection(optional),
          isEmpty,
          reason: 'a field of $name is both required and optional',
        );
      });
    });
  });

  group('the status enumeration', () {
    final declared = _at(<String>[
      'properties',
      'files',
      'additionalProperties',
      'properties',
      'mutants',
      'items',
      'properties',
      'status',
    ]);

    test('matches the schema value for value, in order', () {
      expect(
        MutantStatus.values.map((status) => status.wireName).toList(),
        declared['enum'],
      );
    });

    test('is titled MutantStatus in the schema', () {
      expect(declared['title'], 'MutantStatus');
    });
  });

  group('the schemaVersion pattern', () {
    test('is the pattern the schema declares', () {
      expect(
        MutationTestResult.schemaVersionPattern,
        _at(<String>['properties', 'schemaVersion'])['pattern'],
      );
    });

    test('accepts every example the schema gives', () {
      final examples =
          _at(<String>['properties', 'schemaVersion'])['examples']!
              as List<Object?>;
      expect(examples, isNotEmpty);
      for (final example in examples.cast<String>()) {
        expect(
          RegExp(MutationTestResult.schemaVersionPattern).hasMatch(example),
          isTrue,
          reason: '$example is one of the schema\'s own examples',
        );
      }
    });
  });

  group('the position bounds', () {
    final position = _at(<String>['definitions', 'position']);

    test('are the one-based minimums this package enforces', () {
      final properties = position['properties']! as Map<String, Object?>;
      for (final axis in <String>['line', 'column']) {
        final field = properties[axis]! as Map<String, Object?>;
        expect(field['type'], 'integer');
        expect(field['minimum'], 1, reason: '$axis is one-based');
      }
    });
  });

  group('the threshold bounds', () {
    final thresholds = _at(<String>['properties', 'thresholds']);

    test('are the percentages this package enforces', () {
      final properties = thresholds['properties']! as Map<String, Object?>;
      for (final bound in <String>['high', 'low']) {
        final field = properties[bound]! as Map<String, Object?>;
        expect(field['type'], 'integer');
        expect(field['minimum'], Thresholds.minimumPercentage);
        expect(field['maximum'], Thresholds.maximumPercentage);
      }
    });
  });
}
