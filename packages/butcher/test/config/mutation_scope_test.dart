import 'package:butcher/src/config/butcher_config.dart';
import 'package:butcher/src/config/mutation_scope.dart';
import 'package:test/test.dart';

void main() {
  test('a directory pattern ending in a double star excludes the subtree', () {
    final scope = MutationScope(['lib/src/generated/**']);
    expect(scope.excludes('lib/src/generated/a.dart'), isTrue);
    expect(scope.excludes('lib/src/generated/deep/nested/b.dart'), isTrue);
    expect(scope.excludes('lib/src/kept.dart'), isFalse);
  });

  test('a single-file pattern excludes exactly that file', () {
    final scope = MutationScope(['lib/legacy.dart']);
    expect(scope.excludes('lib/legacy.dart'), isTrue);
    expect(scope.excludes('lib/src/legacy.dart'), isFalse);
  });

  test('a path matching no pattern stays in scope', () {
    final scope = MutationScope(['lib/src/generated/**', 'lib/legacy.dart']);
    expect(scope.excludes('lib/a.dart'), isFalse);
  });

  test('a path matching two patterns at once is excluded once', () {
    final scope = MutationScope(['lib/**', '**/legacy.dart']);
    expect(scope.excludes('lib/legacy.dart'), isTrue);
  });

  test('patterns written with posix separators match on this host', () {
    final scope = MutationScope(['lib/src/**']);
    expect(scope.excludes('lib/src/b.dart'), isTrue);
  });

  test('an empty pattern list excludes nothing', () {
    expect(MutationScope(const []).excludes('lib/a.dart'), isFalse);
  });

  test('order does not affect the result', () {
    final forwards = MutationScope(['lib/**', 'lib/legacy.dart']);
    final backwards = MutationScope(['lib/legacy.dart', 'lib/**']);
    expect(forwards.excludes('lib/legacy.dart'), isTrue);
    expect(backwards.excludes('lib/legacy.dart'), isTrue);
  });

  test('compiles the exclude list of a configuration', () {
    final scope = MutationScope.of(
      const ButcherConfig(exclude: ['lib/src/**']),
    );
    expect(scope.excludes('lib/src/b.dart'), isTrue);
    expect(scope.excludes('lib/a.dart'), isFalse);
  });
}
