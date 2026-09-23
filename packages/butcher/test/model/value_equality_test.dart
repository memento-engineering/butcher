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

const _mutant = Mutant(id: 'lib/a.dart:12:arithmetic', mutation: _mutation);

const _run = TestRun(
  exitCode: 0,
  timedOut: false,
  output: 'suite output',
  errorOutput: 'suite stderr',
  duration: Duration(seconds: 2),
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

  group('Mutant', () {
    test('equals a separately built mutant with the same fields', () {
      const other = Mutant(
        id: 'lib/a.dart:12:arithmetic',
        mutation: Mutation(
          filePath: 'lib/a.dart',
          offset: 12,
          length: 1,
          original: '+',
          replacement: '-',
          mutatorId: 'arithmetic',
          description: 'replace + with -',
        ),
      );

      expect(_mutant, other);
      expect(_mutant.hashCode, other.hashCode);
    });

    test('differs when any single field differs', () {
      expect(
        _mutant,
        isNot(
          const Mutant(id: 'lib/a.dart:99:arithmetic', mutation: _mutation),
        ),
      );
      expect(
        _mutant,
        isNot(
          const Mutant(
            id: 'lib/a.dart:12:arithmetic',
            mutation: Mutation(
              filePath: 'lib/a.dart',
              offset: 12,
              length: 1,
              original: '+',
              replacement: '*',
              mutatorId: 'arithmetic',
              description: 'replace + with -',
            ),
          ),
        ),
      );
    });

    test('carries value semantics into a set and a map key', () {
      const twin = Mutant(id: 'lib/a.dart:12:arithmetic', mutation: _mutation);

      expect({_mutant}, contains(twin));
      expect({_mutant: 'seen'}[twin], 'seen');
    });

    test('names the mutant id', () {
      expect(_mutant.toString(), contains('lib/a.dart:12:arithmetic'));
    });
  });

  group('TestRun', () {
    test('equals a separately built run with the same observable fields', () {
      const other = TestRun(
        exitCode: 0,
        timedOut: false,
        output: 'suite output',
        errorOutput: 'suite stderr',
        duration: Duration(seconds: 2),
      );

      expect(_run, other);
      expect(_run.hashCode, other.hashCode);
    });

    test('ignores the parsed events, which are a view of the output', () {
      final withEvents = TestRun(
        exitCode: 0,
        timedOut: false,
        output: 'suite output',
        errorOutput: 'suite stderr',
        events: TestEvents.parse(
          '{"type":"suite","suite":{"id":0,"path":"test/a_test.dart"}}\n',
        ),
        duration: const Duration(seconds: 2),
      );
      final withOtherEvents = TestRun(
        exitCode: 0,
        timedOut: false,
        output: 'suite output',
        errorOutput: 'suite stderr',
        events: TestEvents.parse(
          '{"type":"suite","suite":{"id":0,"path":"test/b_test.dart"}}\n',
        ),
        duration: const Duration(seconds: 2),
      );

      expect(withEvents, withOtherEvents);
      expect(withEvents.hashCode, withOtherEvents.hashCode);
      expect(withEvents, _run);
      expect(withEvents.hashCode, _run.hashCode);
    });

    test('differs when any single observable field differs', () {
      expect(
        _run,
        isNot(
          const TestRun(
            exitCode: 1,
            timedOut: false,
            output: 'suite output',
            errorOutput: 'suite stderr',
            duration: Duration(seconds: 2),
          ),
        ),
      );
      expect(
        _run,
        isNot(
          const TestRun(
            exitCode: 0,
            timedOut: true,
            output: 'suite output',
            errorOutput: 'suite stderr',
            duration: Duration(seconds: 2),
          ),
        ),
      );
      expect(
        _run,
        isNot(
          const TestRun(
            exitCode: 0,
            timedOut: false,
            output: 'other output',
            errorOutput: 'suite stderr',
            duration: Duration(seconds: 2),
          ),
        ),
      );
      expect(
        _run,
        isNot(
          const TestRun(
            exitCode: 0,
            timedOut: false,
            output: 'suite output',
            errorOutput: 'other stderr',
            duration: Duration(seconds: 2),
          ),
        ),
      );
      expect(
        _run,
        isNot(
          const TestRun(
            exitCode: 0,
            timedOut: false,
            output: 'suite output',
            errorOutput: 'suite stderr',
            duration: Duration(seconds: 3),
          ),
        ),
      );
    });

    test('carries value semantics into a set and a map key', () {
      const twin = TestRun(
        exitCode: 0,
        timedOut: false,
        output: 'suite output',
        errorOutput: 'suite stderr',
        duration: Duration(seconds: 2),
      );

      expect({_run}, contains(twin));
      expect({_run: 'seen'}[twin], 'seen');
    });

    test('names the exit code and the timed-out flag', () {
      final text = _run.toString();

      expect(text, contains('0'));
      expect(text, contains('false'));
    });
  });
}
