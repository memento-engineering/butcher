import 'package:butcher_report/butcher_report.dart';
import 'package:test/test.dart';

const _definition = TestDefinition(
  id: 't1',
  name: 'add returns the sum',
  location: OpenEndLocation(start: Position(line: 7, column: 3)),
);

const _file = TestFile(
  tests: <TestDefinition>[_definition],
  source: "void main() {}\n",
);

void main() {
  group('TestFile', () {
    test('round-trips through the map form', () {
      expect(TestFile.fromJson(_file.toJson()), _file);
    });

    test('names a missing tests list', () {
      for (final field in TestFile.requiredJsonFields) {
        final json = _file.toJson()..remove(field);
        expect(
          () => TestFile.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('TestFile'), contains(field)),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('omits an absent source rather than writing null', () {
      const bare = TestFile(tests: <TestDefinition>[_definition]);
      expect(bare.toJson().keys, <String>['tests']);
      expect(TestFile.fromJson(bare.toJson()), bare);
    });

    test('compares its tests by value', () {
      expect(
        _file,
        isNot(
          const TestFile(tests: <TestDefinition>[], source: "void main() {}\n"),
        ),
      );
    });
  });

  group('TestDefinition', () {
    test('names each missing required field', () {
      for (final field in TestDefinition.requiredJsonFields) {
        final json = _definition.toJson()..remove(field);
        expect(
          () => TestDefinition.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(contains('TestDefinition'), contains(field)),
            ),
          ),
          reason: 'removing $field must be reported by name',
        );
      }
    });

    test('omits an absent location rather than writing null', () {
      const bare = TestDefinition(id: 't1', name: 'add returns the sum');
      expect(bare.toJson().keys, <String>['id', 'name']);
      expect(TestDefinition.fromJson(bare.toJson()), bare);
    });

    test('keeps an open-ended location open', () {
      final json = _definition.toJson();
      final location = json['location']! as Map<String, Object?>;
      expect(location.keys, <String>['start']);
      expect(TestDefinition.fromJson(json), _definition);
    });

    test('has a readable string form', () {
      expect(
        _definition.toString(),
        'TestDefinition(id: t1, name: add returns the sum)',
      );
    });
  });
}
