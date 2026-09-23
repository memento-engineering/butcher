import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

const _mutation = Mutation(
  filePath: 'lib/calc.dart',
  offset: 24,
  length: 1,
  original: '+',
  replacement: '-',
  mutatorId: 'arithmetic',
  description: '+ → -',
);

MutantResult _result({String id = 'calc:24:arithmetic'}) => MutantResult(
  mutant: Mutant(id: id, mutation: _mutation),
  outcome: Outcome.killed,
);

void main() {
  group('RunStarted', () {
    test('is equal to another carrying the same count and timings', () {
      const event = RunStarted(
        mutantCount: 7,
        baseline: Duration(seconds: 2),
        deadline: Duration(seconds: 10),
      );

      expect(
        event,
        const RunStarted(
          mutantCount: 7,
          baseline: Duration(seconds: 2),
          deadline: Duration(seconds: 10),
        ),
      );
      expect(
        event.hashCode,
        const RunStarted(
          mutantCount: 7,
          baseline: Duration(seconds: 2),
          deadline: Duration(seconds: 10),
        ).hashCode,
      );
    });

    test('differs on any one of its three fields', () {
      const event = RunStarted(
        mutantCount: 7,
        baseline: Duration(seconds: 2),
        deadline: Duration(seconds: 10),
      );

      expect(
        event,
        isNot(
          const RunStarted(
            mutantCount: 8,
            baseline: Duration(seconds: 2),
            deadline: Duration(seconds: 10),
          ),
        ),
      );
      expect(
        event,
        isNot(
          const RunStarted(
            mutantCount: 7,
            baseline: Duration(seconds: 3),
            deadline: Duration(seconds: 10),
          ),
        ),
      );
      expect(
        event,
        isNot(
          const RunStarted(
            mutantCount: 7,
            baseline: Duration(seconds: 2),
            deadline: Duration(seconds: 11),
          ),
        ),
      );
    });

    test('names the count and both timings in milliseconds', () {
      expect(
        const RunStarted(
          mutantCount: 7,
          baseline: Duration(seconds: 2),
          deadline: Duration(seconds: 10),
        ).toString(),
        'RunStarted(7 mutants, baseline 2000 ms, deadline 10000 ms)',
      );
    });
  });

  group('MutantClassified', () {
    test('is equal to another carrying an equal result', () {
      expect(MutantClassified(_result()), MutantClassified(_result()));
      expect(
        MutantClassified(_result()).hashCode,
        MutantClassified(_result()).hashCode,
      );
    });

    test('differs when the carried result differs', () {
      expect(
        MutantClassified(_result()),
        isNot(MutantClassified(_result(id: 'calc:99:arithmetic'))),
      );
    });

    test('names the mutant id and the outcome', () {
      expect(
        MutantClassified(_result()).toString(),
        'MutantClassified(calc:24:arithmetic, killed)',
      );
    });
  });

  group('RunCompleted', () {
    test('is equal to every other completion event', () {
      expect(const RunCompleted(), const RunCompleted());
      expect(const RunCompleted().hashCode, const RunCompleted().hashCode);
    });

    test('is not equal to another kind of event', () {
      expect(const RunCompleted(), isNot(MutantClassified(_result())));
    });

    test('names the event', () {
      expect(const RunCompleted().toString(), 'RunCompleted()');
    });
  });

  test('every event is a RunEvent', () {
    const events = <RunEvent>[
      RunStarted(
        mutantCount: 1,
        baseline: Duration.zero,
        deadline: Duration.zero,
      ),
      RunCompleted(),
    ];

    expect(events, everyElement(isA<RunEvent>()));
    expect(MutantClassified(_result()), isA<RunEvent>());
  });
}
