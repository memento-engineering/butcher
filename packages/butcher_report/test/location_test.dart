import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

void main() {
  group('Position', () {
    test('round-trips through the map form', () {
      const position = Position(line: 4, column: 3);
      expect(position.toJson(), <String, Object?>{'line': 4, 'column': 3});
      expect(Position.fromJson(position.toJson()), position);
    });

    test('equality distinguishes a differing column', () {
      expect(
        const Position(line: 4, column: 3),
        isNot(const Position(line: 4, column: 4)),
      );
      expect(
        const Position(line: 4, column: 3).hashCode,
        const Position(line: 4, column: 3).hashCode,
      );
    });

    test('names a missing required field', () {
      for (final field in Position.requiredJsonFields) {
        final json = <String, Object?>{'line': 4, 'column': 3}..remove(field);
        expect(
          () => Position.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('Position'), contains(field)),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('rejects a zero-based line or column', () {
      expect(
        () => Position.fromJson(<String, Object?>{'line': 0, 'column': 3}),
        throwsFormatException,
      );
      expect(
        () => Position.fromJson(<String, Object?>{'line': 4, 'column': 0}),
        throwsFormatException,
      );
    });

    test('rejects a non-integer line', () {
      expect(
        () => Position.fromJson(<String, Object?>{'line': 4.5, 'column': 3}),
        throwsFormatException,
      );
    });

    test('has a readable string form', () {
      expect(
        const Position(line: 4, column: 3).toString(),
        'Position(line: 4, column: 3)',
      );
    });
  });

  group('Location', () {
    const location = Location(
      start: Position(line: 4, column: 3),
      end: Position(line: 4, column: 9),
    );

    test('round-trips through the map form', () {
      expect(location.toJson(), <String, Object?>{
        'start': <String, Object?>{'line': 4, 'column': 3},
        'end': <String, Object?>{'line': 4, 'column': 9},
      });
      expect(Location.fromJson(location.toJson()), location);
    });

    test('equality distinguishes a differing column', () {
      expect(
        location,
        isNot(
          const Location(
            start: Position(line: 4, column: 3),
            end: Position(line: 4, column: 8),
          ),
        ),
      );
    });

    test('names a missing required field', () {
      for (final field in Location.requiredJsonFields) {
        final json = location.toJson()..remove(field);
        expect(
          () => Location.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('Location'), contains(field)),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('rejects a non-object body', () {
      expect(() => Location.fromJson('4:3-4:9'), throwsFormatException);
    });
  });

  group('OpenEndLocation', () {
    test('omits an absent end rather than writing null', () {
      const location = OpenEndLocation(start: Position(line: 12, column: 1));
      expect(location.toJson().keys, <String>['start']);
      expect(OpenEndLocation.fromJson(location.toJson()), location);
    });

    test('round-trips a present end', () {
      const location = OpenEndLocation(
        start: Position(line: 12, column: 1),
        end: Position(line: 18, column: 2),
      );
      expect(OpenEndLocation.fromJson(location.toJson()), location);
      expect(
        location,
        isNot(const OpenEndLocation(start: Position(line: 12, column: 1))),
      );
    });

    test('names a missing start', () {
      expect(
        () => OpenEndLocation.fromJson(<String, Object?>{}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('OpenEndLocation'), contains('start')),
          ),
        ),
      );
    });
  });
}
