import 'dart:collection';

/// Accumulates process output while retaining at most [limit] characters
/// plus the dead prefix of the oldest chunk still held: a mutant that loops
/// over `print` can emit gigabytes within its half-life, so streams are
/// bounded while they are read instead of after the fact.
///
/// Dropping whole chunks off the front keeps a write proportional to the
/// chunk and never to the tail: every worker shares one isolate, and a flood
/// that recopied its tail per chunk would stall the others.
///
/// The cap exists only to survive such a runaway mutant, never to trim
/// ordinary output: dropping the middle of a parsed stream silently changes
/// verdicts, so every limit belongs far above what a real suite emits.
final class CappedOutput {
  /// Creates a buffer retaining at most [limit] characters.
  CappedOutput({required this.limit});

  /// Maximum number of characters retained.
  final int limit;

  final _head = StringBuffer();
  final _tail = ListQueue<String>();
  var _tailLength = 0;

  /// Characters of [_tail]'s oldest chunk that were already dropped.
  var _front = 0;
  var _dropped = 0;

  /// Appends [chunk], dropping the oldest characters past the head once
  /// [limit] is reached.
  void write(String chunk) {
    final room = limit ~/ 2 - _head.length;
    if (room >= chunk.length) {
      _head.write(chunk);
      return;
    }
    if (room > 0) {
      _head.write(chunk.substring(0, room));
      chunk = chunk.substring(room);
    }
    _tail.add(chunk);
    _tailLength += chunk.length;
    var drop = _tailLength - (limit - limit ~/ 2);
    if (drop <= 0) return;
    _dropped += drop;
    _tailLength -= drop;
    while (_tail.isNotEmpty && drop >= _tail.first.length - _front) {
      drop -= _tail.removeFirst().length - _front;
      _front = 0;
    }
    _front += drop;
  }

  String get _tailText {
    if (_tail.isEmpty) return '';
    final buffer = StringBuffer(_tail.first.substring(_front));
    for (final chunk in _tail.skip(1)) {
      buffer.write(chunk);
    }
    return '$buffer';
  }

  @override
  String toString() => _dropped == 0
      ? '$_head$_tailText'
      : '$_head\n[rad] truncated $_dropped characters\n$_tailText';
}
