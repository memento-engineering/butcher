import 'dart:convert';
import 'dart:io';

import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

/// One public type's sample, built through [parse] so each call is a distinct
/// instance: a const literal would be canonicalized and prove nothing.
typedef Sample = ({
  Object Function(Object? json) parse,
  Map<String, Object?> json,
  Map<String, Object?> other,
});

const _location = <String, Object?>{
  'start': <String, Object?>{'line': 4, 'column': 3},
  'end': <String, Object?>{'line': 4, 'column': 9},
};

const _mutant = <String, Object?>{
  'id': '1',
  'mutatorName': 'BinaryExpression',
  'location': _location,
  'status': 'Killed',
  'coveredBy': <String>['t1'],
};

const _fileResult = <String, Object?>{
  'language': 'dart',
  'source': 'int add(int a, int b) => a + b;\n',
  'mutants': <Object?>[_mutant],
};

final _samples = <String, Sample>{
  'Position': (
    parse: Position.fromJson,
    json: <String, Object?>{'line': 4, 'column': 3},
    other: <String, Object?>{'line': 4, 'column': 4},
  ),
  'Location': (
    parse: Location.fromJson,
    json: _location,
    other: <String, Object?>{
      'start': <String, Object?>{'line': 4, 'column': 3},
      'end': <String, Object?>{'line': 5, 'column': 1},
    },
  ),
  'OpenEndLocation': (
    parse: OpenEndLocation.fromJson,
    json: <String, Object?>{
      'start': <String, Object?>{'line': 4, 'column': 3},
    },
    other: _location,
  ),
  'ReportMutant': (
    parse: ReportMutant.fromJson,
    json: _mutant,
    other: <String, Object?>{
      ..._mutant,
      'coveredBy': <String>['t2'],
    },
  ),
  'FileResult': (
    parse: FileResult.fromJson,
    json: _fileResult,
    other: <String, Object?>{..._fileResult, 'mutants': <Object?>[]},
  ),
  'Thresholds': (
    parse: Thresholds.fromJson,
    json: <String, Object?>{'high': 80, 'low': 60},
    other: <String, Object?>{'high': 80, 'low': 61},
  ),
  'TestDefinition': (
    parse: TestDefinition.fromJson,
    json: <String, Object?>{'id': 't1', 'name': 'adds'},
    other: <String, Object?>{'id': 't1', 'name': 'subtracts'},
  ),
  'TestFile': (
    parse: TestFile.fromJson,
    json: <String, Object?>{
      'tests': <Object?>[
        <String, Object?>{'id': 't1', 'name': 'adds'},
      ],
    },
    other: <String, Object?>{'tests': <Object?>[]},
  ),
  'PerformanceStatistics': (
    parse: PerformanceStatistics.fromJson,
    json: <String, Object?>{'setup': 1, 'initialRun': 2, 'mutation': 3},
    other: <String, Object?>{'setup': 1, 'initialRun': 2, 'mutation': 4},
  ),
  'BrandingInformation': (
    parse: BrandingInformation.fromJson,
    json: <String, Object?>{'homepageUrl': 'https://example.invalid'},
    other: <String, Object?>{'homepageUrl': 'https://example.test'},
  ),
  'FrameworkInformation': (
    parse: FrameworkInformation.fromJson,
    json: <String, Object?>{
      'name': 'butcher',
      'dependencies': <String, Object?>{'analyzer': '8.4.0'},
    },
    other: <String, Object?>{
      'name': 'butcher',
      'dependencies': <String, Object?>{'analyzer': '8.5.0'},
    },
  ),
  'OsInformation': (
    parse: OsInformation.fromJson,
    json: <String, Object?>{'platform': 'linux'},
    other: <String, Object?>{'platform': 'macos'},
  ),
  'CpuInformation': (
    parse: CpuInformation.fromJson,
    json: <String, Object?>{'logicalCores': 10},
    other: <String, Object?>{'logicalCores': 8},
  ),
  'RamInformation': (
    parse: RamInformation.fromJson,
    json: <String, Object?>{'total': 32768},
    other: <String, Object?>{'total': 16384},
  ),
  'SystemInformation': (
    parse: SystemInformation.fromJson,
    json: <String, Object?>{
      'ci': true,
      'os': <String, Object?>{'platform': 'linux'},
    },
    other: <String, Object?>{
      'ci': false,
      'os': <String, Object?>{'platform': 'linux'},
    },
  ),
  'MutationTestResult': (
    parse: MutationTestResult.fromJson,
    json: <String, Object?>{
      'schemaVersion': '1',
      'thresholds': <String, Object?>{'high': 80, 'low': 60},
      'files': <String, Object?>{'lib/src/adder.dart': _fileResult},
    },
    other: <String, Object?>{
      'schemaVersion': '2',
      'thresholds': <String, Object?>{'high': 80, 'low': 60},
      'files': <String, Object?>{'lib/src/adder.dart': _fileResult},
    },
  ),
};

void main() {
  group('value semantics', () {
    _samples.forEach((name, sample) {
      test('$name is a value in a set and as a map key', () {
        final first = sample.parse(sample.json);
        final second = sample.parse(sample.json);
        final different = sample.parse(sample.other);

        expect(identical(first, second), isFalse, reason: 'distinct instances');
        expect(first, second);
        expect(first.hashCode, second.hashCode);
        expect(first, isNot(different));

        expect(<Object>{first, second}, hasLength(1));
        expect(<Object>{first}.contains(second), isTrue);
        expect(<Object>{first}.contains(different), isFalse);

        final byValue = <Object, String>{first: name};
        expect(byValue[second], name);
        expect(byValue[different], isNull);
        expect(byValue.containsKey(second), isTrue);
      });

      test('$name has a string form naming its type', () {
        expect(sample.parse(sample.json).toString(), startsWith(name));
      });

      test('$name is not equal to an unrelated object', () {
        expect(sample.parse(sample.json), isNot(Object()));
      });
    });

    test('MutantStatus is usable as a set element and a map key', () {
      final counts = <MutantStatus, int>{
        for (final status in MutantStatus.values) status: 0,
      };
      expect(counts, hasLength(MutantStatus.values.length));
      expect(counts[MutantStatus.fromWireName('Pending')], 0);
      expect(MutantStatus.values.toSet(), hasLength(8));
    });

    test('a whole golden report is a value', () {
      final source = File('test/fixtures/full_report.json').readAsStringSync();
      final decoded = jsonDecode(source) as Map<String, Object?>;
      final first = parseMutationTestReport(source);
      final second = parseMutationTestReportJson(decoded);
      expect(identical(first, second), isFalse);
      expect(<MutationTestResult>{first, second}, hasLength(1));
      expect(<MutationTestResult, String>{first: 'golden'}[second], 'golden');
    });
  });
}
