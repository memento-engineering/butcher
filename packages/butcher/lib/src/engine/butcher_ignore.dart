import 'dart:io';

import 'package:path/path.dart' as p;

/// Name of the consumer exclusion file, gitignore-style, at the project root.
const butcherIgnoreFile = '.butcherignore';

/// Gitignore-style exclusion rules shared by generation and sandbox
/// (ADR 0004): comments, negation, directory rules, and anchoring.
final class ButcherIgnore {
  /// Parses [lines] in order; later rules win.
  ButcherIgnore(List<String> lines)
    : _rules = lines.map(_Rule.parse).nonNulls.toList();

  /// Loads the project's `.butcherignore`; missing file means no rules.
  factory ButcherIgnore.load(String projectRoot) {
    final file = File(p.join(projectRoot, butcherIgnoreFile));
    return ButcherIgnore(file.existsSync() ? file.readAsLinesSync() : const []);
  }

  final List<_Rule> _rules;

  /// True when the project-relative posix path [relative] is excluded,
  /// directly or through an excluded parent directory.
  bool excludes(String relative, {required bool isDirectory}) {
    final segments = p.posix.split(relative);
    for (var i = 1; i < segments.length; i++) {
      if (_matches(segments.take(i).join('/'), isDirectory: true)) return true;
    }
    return _matches(relative, isDirectory: isDirectory);
  }

  bool _matches(String path, {required bool isDirectory}) {
    var ignored = false;
    for (final rule in _rules) {
      if (rule.directoryOnly && !isDirectory) continue;
      if (rule.pattern.hasMatch(path)) ignored = !rule.negated;
    }
    return ignored;
  }
}

final class _Rule {
  _Rule({
    required this.pattern,
    required this.negated,
    required this.directoryOnly,
  });

  final RegExp pattern;
  final bool negated;
  final bool directoryOnly;

  static _Rule? parse(String raw) {
    var line = raw;
    if (line.startsWith('#')) return null;
    while (line.endsWith(' ') && !line.endsWith(r'\ ')) {
      line = line.substring(0, line.length - 1);
    }
    var negated = false;
    if (line.startsWith('!')) {
      negated = true;
      line = line.substring(1);
    } else if (line.startsWith(r'\!') || line.startsWith(r'\#')) {
      line = line.substring(1);
    }
    var directoryOnly = false;
    if (line.endsWith('/')) {
      directoryOnly = true;
      line = line.substring(0, line.length - 1);
    }
    if (line.isEmpty) return null;
    final anchored = line.contains('/');
    if (line.startsWith('/')) line = line.substring(1);
    final regex = StringBuffer('^');
    if (!anchored) regex.write(r'(?:.*/)?');
    _translate(line, regex);
    regex.write(r'$');
    return _Rule(
      pattern: RegExp(regex.toString()),
      negated: negated,
      directoryOnly: directoryOnly,
    );
  }

  static void _translate(String line, StringBuffer out) {
    var i = 0;
    while (i < line.length) {
      final c = line[i];
      if (c == '*') {
        final wholeSegment =
            line.startsWith('**', i) &&
            (i == 0 || line[i - 1] == '/') &&
            (i + 2 == line.length || line[i + 2] == '/');
        if (wholeSegment && i + 2 == line.length) {
          out.write('.*');
          i += 2;
        } else if (wholeSegment) {
          out.write(r'(?:.*/)?');
          i += 3;
        } else {
          out.write('[^/]*');
          i += line.startsWith('**', i) ? 2 : 1;
        }
      } else if (c == '?') {
        out.write('[^/]');
        i++;
      } else if (c == '[') {
        i = _characterClass(line, i, out);
      } else if (c == r'\' && i + 1 < line.length) {
        out.write(RegExp.escape(line[i + 1]));
        i += 2;
      } else {
        out.write(RegExp.escape(c));
        i++;
      }
    }
  }

  static int _characterClass(String line, int start, StringBuffer out) {
    var end = start + 1;
    if (end < line.length && (line[end] == '!' || line[end] == '^')) end++;
    if (end < line.length && line[end] == ']') end++;
    while (end < line.length && line[end] != ']') {
      end++;
    }
    if (end == line.length) {
      out.write(r'\[');
      return start + 1;
    }
    var body = line.substring(start + 1, end);
    if (body.startsWith('!')) body = '^${body.substring(1)}';
    out.write('[$body]');
    return end + 1;
  }
}
