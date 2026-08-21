import 'dart:convert';

import 'package:path/path.dart' as p;

import '../model/line_index.dart';
import '../model/mutant.dart';
import '../model/test_suite.dart';
import 'coverage_provider.dart';

/// Per-line coverage ingested from an `lcov.info` report (ADR 0011).
///
/// A mutant is uncovered when no record exists for its file, or when its line
/// is recorded with zero hits. A line without a record is not an executable
/// statement of its own, so it inherits its file's verdict: covered.
final class LcovCoverageProvider implements CoverageProvider {
  /// Creates a provider over [hits]: project-relative posix file path, to
  /// 1-based line, to execution count.
  LcovCoverageProvider({required this.hits});

  /// Reads the lcov report [text]; `SF:` paths resolve against [projectRoot].
  factory LcovCoverageProvider.parse(
    String text, {
    required String projectRoot,
  }) {
    final root = p.normalize(p.absolute(projectRoot));
    final hits = <String, Map<int, int>>{};
    var current = <int, int>{};
    for (final line in LineSplitter.split(text)) {
      if (line.startsWith('SF:')) {
        current = hits.putIfAbsent(
          _relative(line.substring(3).trim(), root),
          () => {},
        );
      } else if (line.startsWith('DA:')) {
        final fields = line.substring(3).split(',');
        final number = fields.isEmpty ? null : int.tryParse(fields.first);
        final count = fields.length < 2 ? null : int.tryParse(fields[1]);
        if (number == null || count == null) continue;
        current[number] = (current[number] ?? 0) + count;
      }
    }
    return LcovCoverageProvider(hits: hits);
  }

  /// Execution counts, per file, per 1-based line.
  final Map<String, Map<int, int>> hits;

  final Map<String, LineIndex> _indexes = {};

  @override
  void indexSources(Map<String, String> sources) {
    sources.forEach((path, text) => _indexes[path] = LineIndex(text));
  }

  @override
  bool isCovered(Mutant mutant) {
    final file = hits[mutant.mutation.filePath];
    if (file == null) return false;
    final count = file[lineOf(mutant)];
    return count == null || count > 0;
  }

  /// An lcov report names no suites, so routing falls back to the whole one.
  @override
  List<TestSuite>? suitesFor(Mutant mutant) => null;

  /// 1-based line [mutant] sits on, per the indexed sources.
  int lineOf(Mutant mutant) =>
      _indexes[mutant.mutation.filePath]!.lineAt(mutant.mutation.offset);

  /// Project-relative posix path of an `SF:` entry, absolute or relative.
  static String _relative(String source, String root) {
    final path = source.startsWith('file://')
        ? Uri.parse(source).toFilePath()
        : source;
    final absolute = p.isAbsolute(path) ? path : p.join(root, path);
    return p.relative(p.normalize(absolute), from: root).replaceAll(r'\', '/');
  }
}
