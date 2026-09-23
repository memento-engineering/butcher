import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

const _location = Location(
  start: Position(line: 4, column: 3),
  end: Position(line: 4, column: 9),
);

const _minimal = ReportMutant(
  id: '1',
  mutatorName: 'BinaryExpression',
  location: _location,
  status: MutantStatus.killed,
);

const _populated = ReportMutant(
  id: '2',
  mutatorName: 'ConditionalExpression',
  location: _location,
  status: MutantStatus.survived,
  coveredBy: <String>['t1', 't2'],
  description: 'replaced < with <=',
  duration: 12.5,
  killedBy: <String>['t2'],
  replacement: '<=',
  isStatic: true,
  statusReason: 'no assertion failed',
  testsCompleted: 2,
);

void main() {
  group('ReportMutant', () {
    test('a minimal mutant emits exactly the four required keys', () {
      expect(_minimal.toJson().keys, <String>[
        'id',
        'mutatorName',
        'location',
        'status',
      ]);
      expect(_minimal.toJson(), hasLength(4));
    });

    test('a fully populated mutant emits all twelve schema fields', () {
      final json = _populated.toJson();
      expect(json, hasLength(12));
      expect(json.keys.toSet(), <String>{
        ...ReportMutant.requiredJsonFields,
        ...ReportMutant.optionalJsonFields,
      });
    });

    test('round-trips both shapes', () {
      expect(ReportMutant.fromJson(_minimal.toJson()), _minimal);
      expect(ReportMutant.fromJson(_populated.toJson()), _populated);
    });

    test('spells the static flag as the schema does', () {
      expect(_populated.toJson()['static'], isTrue);
      expect(ReportMutant.fromJson(_populated.toJson()).isStatic, isTrue);
    });

    test('names each missing required field', () {
      for (final field in ReportMutant.requiredJsonFields) {
        final json = _populated.toJson()..remove(field);
        expect(
          () => ReportMutant.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains(field),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('rejects an unknown status', () {
      final json = _minimal.toJson()..['status'] = 'Maimed';
      expect(() => ReportMutant.fromJson(json), throwsFormatException);
    });

    test('rejects a non-string id', () {
      final json = _minimal.toJson()..['id'] = 1;
      expect(() => ReportMutant.fromJson(json), throwsFormatException);
    });

    test('rejects a coveredBy that is not an array of strings', () {
      final json = _minimal.toJson()..['coveredBy'] = <Object?>[1];
      expect(() => ReportMutant.fromJson(json), throwsFormatException);
    });

    test('compares the list fields by value', () {
      expect(
        ReportMutant.fromJson(_populated.toJson()),
        _populated,
        reason: 'a freshly built coveredBy list must still compare equal',
      );
      expect(
        _populated,
        isNot(
          ReportMutant.fromJson(
            _populated.toJson()..['coveredBy'] = <String>['t1'],
          ),
        ),
      );
    });

    test('has a readable string form naming the mutator and status', () {
      expect(
        _populated.toString(),
        allOf(contains('ConditionalExpression'), contains('Survived')),
      );
    });
  });
}
