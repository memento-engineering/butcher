import 'package:butcher/src/engine/capped_output.dart';
import 'package:test/test.dart';

void main() {
  test('returns output below the limit unchanged', () {
    final buffer = CappedOutput(limit: 16)
      ..write('one\n')
      ..write('two\n');
    expect('$buffer', 'one\ntwo\n');
  });

  test('keeps head and tail and reports what was dropped', () {
    final buffer = CappedOutput(limit: 8);
    for (var i = 0; i < 5; i++) {
      buffer.write('$i\n');
    }
    expect('$buffer', '0\n1\n\n[butcher] truncated 2 characters\n3\n4\n');
  });

  test('bounds the retained size for a runaway stream', () {
    final buffer = CappedOutput(limit: 1024);
    for (var i = 0; i < 1000; i++) {
      buffer.write('flood ' * 100);
    }
    expect('$buffer'.length, lessThan(1024 + 64));
    expect('$buffer', startsWith('flood '));
    expect('$buffer', endsWith('flood '));
  });

  test('splits a single oversized chunk across head and tail', () {
    final buffer = CappedOutput(limit: 10)..write('abcdefghijklmnop');
    expect('$buffer', 'abcde\n[butcher] truncated 6 characters\nlmnop');
  });

  test('renders the same bytes however the chunks are split', () {
    final buffer = CappedOutput(limit: 10)
      ..write('abc')
      ..write('defgh')
      ..write('ij')
      ..write('klmnop');
    expect('$buffer', 'abcde\n[butcher] truncated 6 characters\nlmnop');
  });

  test('drains a flood at the cost of the flood, not of the limit', () {
    final buffer = CappedOutput(limit: 8 * 1024 * 1024);
    final chunk = 'y' * (64 * 1024);
    for (var i = 0; i < 4096; i++) {
      buffer.write(chunk);
    }
    expect('$buffer'.length, lessThan(8 * 1024 * 1024 + 64));
  });
}
