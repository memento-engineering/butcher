import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

void main() {
  group('Thresholds', () {
    const thresholds = Thresholds(high: 80, low: 60);

    test('round-trips through the map form', () {
      expect(thresholds.toJson(), <String, Object?>{'high': 80, 'low': 60});
      expect(Thresholds.fromJson(thresholds.toJson()), thresholds);
    });

    test('names each missing required field', () {
      for (final field in Thresholds.requiredJsonFields) {
        final json = thresholds.toJson()..remove(field);
        expect(
          () => Thresholds.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('Thresholds'), contains(field)),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('accepts both ends of the percentage range', () {
      expect(
        Thresholds.fromJson(<String, Object?>{'high': 100, 'low': 0}),
        const Thresholds(high: 100, low: 0),
      );
    });

    test('rejects a percentage outside the range', () {
      expect(
        () => Thresholds.fromJson(<String, Object?>{'high': 101, 'low': 60}),
        throwsFormatException,
      );
      expect(
        () => Thresholds.fromJson(<String, Object?>{'high': 80, 'low': -1}),
        throwsFormatException,
      );
    });

    test('rejects a non-integer percentage', () {
      expect(
        () => Thresholds.fromJson(<String, Object?>{'high': 80.5, 'low': 60}),
        throwsFormatException,
      );
    });

    test('compares by value and has a readable string form', () {
      expect(thresholds, const Thresholds(high: 80, low: 60));
      expect(thresholds, isNot(const Thresholds(high: 80, low: 61)));
      expect(thresholds.toString(), 'Thresholds(high: 80, low: 60)');
    });
  });
}
