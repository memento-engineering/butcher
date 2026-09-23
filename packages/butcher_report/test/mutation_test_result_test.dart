import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

const _result = MutationTestResult(
  schemaVersion: '1',
  thresholds: Thresholds(high: 80, low: 60),
  files: <String, FileResult>{
    'lib/src/adder.dart': FileResult(
      language: 'dart',
      source: 'int add(int a, int b) => a + b;\n',
      mutants: <ReportMutant>[
        ReportMutant(
          id: '1',
          mutatorName: 'BinaryExpression',
          location: Location(
            start: Position(line: 1, column: 27),
            end: Position(line: 1, column: 32),
          ),
          status: MutantStatus.killed,
        ),
      ],
    ),
  },
);

void main() {
  group('MutationTestResult', () {
    test('round-trips the minimal required shape', () {
      expect(_result.toJson().keys, <String>[
        'schemaVersion',
        'thresholds',
        'files',
      ]);
      expect(MutationTestResult.fromJson(_result.toJson()), _result);
    });

    test('accepts every version the schema pattern allows', () {
      for (final version in <String>['1', '2', '1.0', '2.0', '2.0.0', '1.12']) {
        final json = _result.toJson()..['schemaVersion'] = version;
        expect(
          MutationTestResult.fromJson(json).schemaVersion,
          version,
          reason: '$version is inside the schema pattern',
        );
      }
    });

    test('throws on a version outside the allowed major range', () {
      for (final version in <String>['0', '3', '10', '3.0.0']) {
        final json = _result.toJson()..['schemaVersion'] = version;
        expect(
          () => MutationTestResult.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('schemaVersion'), contains(version)),
            ),
          ),
          reason: '$version is outside the schema pattern',
        );
      }
    });

    test('throws on a version with too many parts or a leading zero', () {
      for (final version in <String>['1.0.0.0', '1.01', '', '1.']) {
        final json = _result.toJson()..['schemaVersion'] = version;
        expect(
          () => MutationTestResult.fromJson(json),
          throwsFormatException,
          reason: '"$version" is outside the schema pattern',
        );
      }
    });

    test('names each missing required field', () {
      for (final field in MutationTestResult.requiredJsonFields) {
        final json = _result.toJson()..remove(field);
        expect(
          () => MutationTestResult.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('MutationTestResult'), contains(field)),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('throws when the files dictionary is missing', () {
      final json = _result.toJson()..remove('files');
      expect(
        () => MutationTestResult.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('files'),
          ),
        ),
      );
    });

    test('accepts an empty files dictionary', () {
      final json = _result.toJson()..['files'] = <String, Object?>{};
      expect(MutationTestResult.fromJson(json).files, isEmpty);
    });

    test('keeps the free-form config as decoded', () {
      final json = _result.toJson()
        ..['config'] = <String, Object?>{
          'concurrency': 4,
          'nested': <String, Object?>{
            'list': <Object?>[1, 'two', null],
          },
        };
      final parsed = MutationTestResult.fromJson(json);
      expect(parsed.config, json['config']);
      expect(parsed.toJson()['config'], json['config']);
    });

    test('compares a free-form config by value', () {
      final left = MutationTestResult.fromJson(
        _result.toJson()
          ..['config'] = <String, Object?>{
            'a': <Object?>[1, 2],
          },
      );
      final right = MutationTestResult.fromJson(
        _result.toJson()
          ..['config'] = <String, Object?>{
            'a': <Object?>[1, 2],
          },
      );
      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect(
        left,
        isNot(
          MutationTestResult.fromJson(
            _result.toJson()
              ..['config'] = <String, Object?>{
                'a': <Object?>[1, 3],
              },
          ),
        ),
      );
    });

    test('has a readable string form', () {
      expect(
        _result.toString(),
        allOf(contains('schemaVersion: 1'), contains('files: 1')),
      );
    });
  });
}
