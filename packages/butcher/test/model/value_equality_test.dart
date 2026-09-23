import 'package:butcher/butcher.dart';
import 'package:butcher/src/engine/capped_output.dart';
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

const _result = MutantResult(
  mutant: _mutant,
  outcome: Outcome.killed,
  testRun: _run,
  error: null,
);

// Const twins are canonicalized to one instance, which identity equality
// would satisfy on its own, so every equal pair below is built at runtime:
// the assertions then really exercise the operators. The const fields above
// carry the separate requirement that all five still compile as const.
Mutation _buildMutation() => Mutation(
  filePath: 'lib/a.dart',
  offset: 12,
  length: 1,
  original: '+',
  replacement: '-',
  mutatorId: 'arithmetic',
  description: 'replace + with -',
);

TestSuite _buildSuite() =>
    TestSuite(path: 'test/a_test.dart', duration: Duration(milliseconds: 300));

Mutant _buildMutant() =>
    Mutant(id: 'lib/a.dart:12:arithmetic', mutation: _buildMutation());

TestRun _buildRun({TestEvents? events}) => TestRun(
  exitCode: 0,
  timedOut: false,
  output: 'suite output',
  errorOutput: 'suite stderr',
  events: events,
  duration: Duration(seconds: 2),
);

MutantResult _buildResult() => MutantResult(
  mutant: _buildMutant(),
  outcome: Outcome.killed,
  testRun: _buildRun(),
);

void main() {
  group('Mutation', () {
    test('equals a separately built mutation with the same fields', () {
      final other = _buildMutation();

      expect(other, isNot(same(_mutation)));
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
      final twin = _buildMutation();

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
      final other = _buildSuite();

      expect(other, isNot(same(_suite)));
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
      final twin = _buildSuite();

      expect({_suite}, contains(twin));
      expect({_suite: 'seen'}[twin], 'seen');
    });

    test('names the suite path', () {
      expect(_suite.toString(), contains('test/a_test.dart'));
    });
  });

  group('Mutant', () {
    test('equals a separately built mutant with the same fields', () {
      final other = _buildMutant();

      expect(other, isNot(same(_mutant)));
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
      final twin = _buildMutant();

      expect({_mutant}, contains(twin));
      expect({_mutant: 'seen'}[twin], 'seen');
    });

    test('names the mutant id', () {
      expect(_mutant.toString(), contains('lib/a.dart:12:arithmetic'));
    });
  });

  group('TestRun', () {
    test('equals a separately built run with the same observable fields', () {
      final other = _buildRun();

      expect(other, isNot(same(_run)));
      expect(_run, other);
      expect(_run.hashCode, other.hashCode);
    });

    test('ignores the parsed events, which are a view of the output', () {
      final withEvents = _buildRun(
        events: TestEvents.parse(
          '{"type":"suite","suite":{"id":0,"path":"test/a_test.dart"}}\n',
        ),
      );
      final withOtherEvents = _buildRun(
        events: TestEvents.parse(
          '{"type":"suite","suite":{"id":0,"path":"test/b_test.dart"}}\n',
        ),
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
      final twin = _buildRun();

      expect({_run}, contains(twin));
      expect({_run: 'seen'}[twin], 'seen');
    });

    test('names the exit code and the timed-out flag', () {
      final text = _run.toString();

      expect(text, contains('0'));
      expect(text, contains('false'));
    });
  });

  group('MutantResult', () {
    test('equals a separately built result with the same fields', () {
      final other = _buildResult();

      expect(other, isNot(same(_result)));
      expect(_result, other);
      expect(_result.hashCode, other.hashCode);
    });

    test('differs when any single field differs', () {
      expect(
        _result,
        isNot(
          const MutantResult(
            mutant: Mutant(id: 'lib/a.dart:99:arithmetic', mutation: _mutation),
            outcome: Outcome.killed,
            testRun: _run,
          ),
        ),
      );
      expect(
        _result,
        isNot(
          const MutantResult(
            mutant: _mutant,
            outcome: Outcome.survived,
            testRun: _run,
          ),
        ),
      );
      expect(
        _result,
        isNot(const MutantResult(mutant: _mutant, outcome: Outcome.killed)),
      );
      expect(
        _result,
        isNot(
          const MutantResult(
            mutant: _mutant,
            outcome: Outcome.killed,
            testRun: _run,
            error: 'boom',
          ),
        ),
      );
    });

    test('carries value semantics into a set and a map key', () {
      final twin = _buildResult();

      expect({_result}, contains(twin));
      expect({_result: 'seen'}[twin], 'seen');
    });

    test('names the mutant id and the outcome', () {
      final text = _result.toString();

      expect(text, contains('lib/a.dart:12:arithmetic'));
      expect(text, contains('killed'));
    });
  });

  group('the mechanism classes stay identity-compared', () {
    test('two capped buffers holding the same content are not equal', () {
      final one = CappedOutput(limit: 64)..write('same content');
      final other = CappedOutput(limit: 64)..write('same content');

      expect(one.toString(), other.toString());
      expect(one, isNot(other));
      expect({one}, isNot(contains(other)));
      expect(one, same(one));
    });
  });
}
