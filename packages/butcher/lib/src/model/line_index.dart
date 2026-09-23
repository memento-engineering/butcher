/// Maps offsets in one source text to 1-based line and column numbers.
final class LineIndex {
  /// Indexes the line starts of [source] once.
  LineIndex(String source) : _starts = _startsOf(source);

  final List<int> _starts;

  /// 1-based line holding [offset].
  int lineAt(int offset) {
    var low = 0;
    var high = _starts.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (_starts[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low + 1;
  }

  /// 1-based column of [offset] within its line.
  int columnAt(int offset) => offset - _starts[lineAt(offset) - 1] + 1;

  static List<int> _startsOf(String source) {
    final starts = [0];
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 0x0A) starts.add(i + 1);
    }
    return starts;
  }
}
