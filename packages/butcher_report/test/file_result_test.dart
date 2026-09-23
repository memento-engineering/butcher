import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

const _mutant = ReportMutant(
  id: '1',
  mutatorName: 'BinaryExpression',
  location: Location(
    start: Position(line: 1, column: 1),
    end: Position(line: 1, column: 2),
  ),
  status: MutantStatus.killed,
);

const _result = FileResult(
  language: 'dart',
  source: 'int add(int a, int b) => a + b;\n',
  mutants: <ReportMutant>[_mutant],
);

void main() {
  group('FileResult', () {
    test('round-trips through the map form', () {
      expect(FileResult.fromJson(_result.toJson()), _result);
      expect(_result.toJson().keys, <String>['language', 'source', 'mutants']);
    });

    test('names each missing required field', () {
      for (final field in FileResult.requiredJsonFields) {
        final json = _result.toJson()..remove(field);
        expect(
          () => FileResult.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('FileResult'), contains(field)),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('carries a mutant-level failure out by that mutant\'s type', () {
      final json = _result.toJson();
      (json['mutants']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .single
          .remove('status');
      expect(
        () => FileResult.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('MutantResult'), contains('status')),
          ),
        ),
      );
    });

    test('accepts a file with no mutants', () {
      const empty = FileResult(
        language: 'dart',
        source: '',
        mutants: <ReportMutant>[],
      );
      expect(FileResult.fromJson(empty.toJson()), empty);
    });

    test('compares its mutants by value', () {
      expect(FileResult.fromJson(_result.toJson()), _result);
      expect(
        _result,
        isNot(
          const FileResult(
            language: 'dart',
            source: 'int add(int a, int b) => a + b;\n',
            mutants: <ReportMutant>[],
          ),
        ),
      );
    });

    test('has a readable string form', () {
      expect(
        _result.toString(),
        allOf(contains('dart'), contains('mutants: 1')),
      );
    });
  });
}
