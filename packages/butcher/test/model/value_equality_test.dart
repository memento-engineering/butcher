import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

const _mutation = Mutation(
  filePath: 'lib/a.dart',
  offset: 12,
  length: 1,
  original: '+',
  replacement: '-',
  mutatorId: 'arithmetic',
  description: 'replace + with -',
);

const _suite = TestSuite(
  path: 'test/a_test.dart',
  duration: Duration(milliseconds: 300),
);

void main() {
  group('Mutation', () {
    test('equals a separately built mutation with the same fields', () {
      const other = Mutation(
        filePath: 'lib/a.dart',
        offset: 12,
        length: 1,
        original: '+',
        replacement: '-',
        mutatorId: 'arithmetic',
        description: 'replace + with -',
      );

      expect(_mutation, other);
      expect(_mutation.hashCode, other.hashCode);
    });

    test('differs when any single field differs', () {
      expect(
        _mutation,
        isNot(
          const Mutation(
            filePath: 'lib/b.dart',
            offset: 12,
            length: 1,
            original: '+',
            replacement: '-',
            mutatorId: 'arithmetic',
            description: 'replace + with -',
          ),
        ),
      );
      expect(
        _mutation,
        isNot(
          const Mutation(
            filePath: 'lib/a.dart',
            offset: 13,
            length: 1,
            original: '+',
            replacement: '-',
            mutatorId: 'arithmetic',
            description: 'replace + with -',
          ),
        ),
      );
      expect(
        _mutation,
        isNot(
          const Mutation(
            filePath: 'lib/a.dart',
            offset: 12,
            length: 2,
            original: '+',
            replacement: '-',
            mutatorId: 'arithmetic',
            description: 'replace + with -',
          ),
        ),
      );
      expect(
        _mutation,
        isNot(
          const Mutation(
            filePath: 'lib/a.dart',
            offset: 12,
            length: 1,
            original: '*',
            replacement: '-',
            mutatorId: 'arithmetic',
            description: 'replace + with -',
          ),
        ),
      );
      expect(
        _mutation,
        isNot(
          const Mutation(
            filePath: 'lib/a.dart',
            offset: 12,
            length: 1,
            original: '+',
            replacement: '*',
            mutatorId: 'arithmetic',
            description: 'replace + with -',
          ),
        ),
      );
      expect(
        _mutation,
        isNot(
          const Mutation(
            filePath: 'lib/a.dart',
            offset: 12,
            length: 1,
            original: '+',
            replacement: '-',
            mutatorId: 'bool-literal',
            description: 'replace + with -',
          ),
        ),
      );
      expect(
        _mutation,
        isNot(
          const Mutation(
            filePath: 'lib/a.dart',
            offset: 12,
            length: 1,
            original: '+',
            replacement: '-',
            mutatorId: 'arithmetic',
            description: 'something else',
          ),
        ),
      );
    });

    test('carries value semantics into a set and a map key', () {
      const twin = Mutation(
        filePath: 'lib/a.dart',
        offset: 12,
        length: 1,
        original: '+',
        replacement: '-',
        mutatorId: 'arithmetic',
        description: 'replace + with -',
      );

      expect({_mutation}, contains(twin));
      expect({_mutation: 'seen'}[twin], 'seen');
    });

    test('names the file, the offset and the replacement', () {
      final text = _mutation.toString();

      expect(text, contains('lib/a.dart'));
      expect(text, contains('12'));
      expect(text, contains('-'));
    });
  });

  group('TestSuite', () {
    test('equals a separately built suite with the same fields', () {
      const other = TestSuite(
        path: 'test/a_test.dart',
        duration: Duration(milliseconds: 300),
      );

      expect(_suite, other);
      expect(_suite.hashCode, other.hashCode);
    });

    test('differs when any single field differs', () {
      expect(
        _suite,
        isNot(
          const TestSuite(
            path: 'test/b_test.dart',
            duration: Duration(milliseconds: 300),
          ),
        ),
      );
      expect(
        _suite,
        isNot(
          const TestSuite(
            path: 'test/a_test.dart',
            duration: Duration(milliseconds: 301),
          ),
        ),
      );
    });

    test('carries value semantics into a set and a map key', () {
      const twin = TestSuite(
        path: 'test/a_test.dart',
        duration: Duration(milliseconds: 300),
      );

      expect({_suite}, contains(twin));
      expect({_suite: 'seen'}[twin], 'seen');
    });

    test('names the suite path', () {
      expect(_suite.toString(), contains('test/a_test.dart'));
    });
  });
}
