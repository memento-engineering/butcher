import 'package:radioactive_dart/src/engine/rad_ignore.dart';
import 'package:test/test.dart';

void main() {
  bool file(RadIgnore ignore, String path) =>
      ignore.excludes(path, isDirectory: false);
  bool dir(RadIgnore ignore, String path) =>
      ignore.excludes(path, isDirectory: true);

  test('skips comments and blank lines', () {
    final ignore = RadIgnore(['# note', '', '   ']);
    expect(file(ignore, '# note'), isFalse);
  });

  test('unanchored patterns match at any depth', () {
    final ignore = RadIgnore(['*.log']);
    expect(file(ignore, 'a.log'), isTrue);
    expect(file(ignore, 'deep/nested/a.log'), isTrue);
    expect(file(ignore, 'a.log.txt'), isFalse);
  });

  test('patterns with a slash are anchored to the root', () {
    final ignore = RadIgnore(['assets/big', '/top.txt']);
    expect(file(ignore, 'assets/big'), isTrue);
    expect(file(ignore, 'nested/assets/big'), isFalse);
    expect(file(ignore, 'top.txt'), isTrue);
    expect(file(ignore, 'nested/top.txt'), isFalse);
  });

  test('directory rules match directories and their contents only', () {
    final ignore = RadIgnore(['build/']);
    expect(dir(ignore, 'build'), isTrue);
    expect(file(ignore, 'build/out.txt'), isTrue);
    expect(file(ignore, 'build'), isFalse);
    expect(dir(ignore, 'sub/build'), isTrue);
  });

  test('negation re-includes with last match winning', () {
    final ignore = RadIgnore(['assets/*', '!assets/keep.txt']);
    expect(file(ignore, 'assets/drop.txt'), isTrue);
    expect(file(ignore, 'assets/keep.txt'), isFalse);
  });

  test('negation cannot re-include inside an excluded directory', () {
    final ignore = RadIgnore(['assets/', '!assets/keep.txt']);
    expect(file(ignore, 'assets/keep.txt'), isTrue);
  });

  test('star does not cross directories but double star does', () {
    final ignore = RadIgnore(['a/*.txt', 'b/**']);
    expect(file(ignore, 'a/x.txt'), isTrue);
    expect(file(ignore, 'a/sub/x.txt'), isFalse);
    expect(file(ignore, 'b/sub/x.txt'), isTrue);
    expect(dir(ignore, 'b'), isFalse);
  });

  test('supports leading and infix double star', () {
    final ignore = RadIgnore(['**/gen', 'a/**/z.txt']);
    expect(dir(ignore, 'deep/gen'), isTrue);
    expect(file(ignore, 'a/z.txt'), isTrue);
    expect(file(ignore, 'a/b/c/z.txt'), isTrue);
  });

  test('supports question marks and character classes', () {
    final ignore = RadIgnore(['file?.txt', 'img[0-9].png']);
    expect(file(ignore, 'file1.txt'), isTrue);
    expect(file(ignore, 'file12.txt'), isFalse);
    expect(file(ignore, 'img7.png'), isTrue);
    expect(file(ignore, 'imgx.png'), isFalse);
  });

  test('escapes literal hash and bang prefixes', () {
    final ignore = RadIgnore([r'\#literal', r'\!bang']);
    expect(file(ignore, '#literal'), isTrue);
    expect(file(ignore, '!bang'), isTrue);
  });

  test('loads no rules when the file is missing', () {
    final ignore = RadIgnore.load('/nonexistent/project/root');
    expect(file(ignore, 'anything'), isFalse);
  });
}
