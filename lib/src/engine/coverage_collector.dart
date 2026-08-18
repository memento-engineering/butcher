import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/test_events.dart';
import 'lcov_coverage_provider.dart';
import 'run_aborted.dart';
import 'test_runner.dart';

/// Collects per-line coverage from one instrumented suite run (ADR 0020).
final class CoverageCollector {
  /// Collects inside the containment at [root]; the suite writes its per-suite
  /// reports into [outputDir].
  CoverageCollector({required this.root, required this.outputDir});

  /// Containment root every collected path is relativized against.
  final String root;

  /// Directory `dart test --coverage` writes its per-suite reports into.
  final String outputDir;

  /// Runs the whole suite through [runner] and returns what it recorded,
  /// keyed by project-relative posix path.
  Future<LcovCoverageProvider> collect(TestRunner runner) async {
    final run = await runner.run(coverageDir: outputDir);
    if (run.exitCode != 0) {
      // Falling back to full coverage would inflate the score (ADR 0013).
      final summary = (run.events ?? TestEvents.parse(run.output)).summarize();
      throw RunAborted(
        'coverage collection failed with exit ${run.exitCode}; rerun with '
        '--no-collect-coverage to treat all code as covered.\n'
        '${summary.isEmpty ? run.errorOutput : summary}',
      );
    }
    final hits = _read();
    if (hits.isEmpty) {
      // A green suite always records the sources it loaded, so an empty
      // result means the measurement failed, not that nothing is covered;
      // routing on it would report every mutant as `noCoverage` (ADR 0020).
      throw RunAborted(
        'coverage collection recorded nothing; rerun with '
        '--no-collect-coverage to treat all code as covered.',
      );
    }
    return LcovCoverageProvider(hits: hits);
  }

  /// Merges every emitted report; one file can be recorded by several suites.
  Map<String, Map<int, int>> _read() {
    final hits = <String, Map<int, int>>{};
    final reports = Directory(outputDir);
    if (!reports.existsSync()) return hits;
    final packages = _packageLibraries();
    final realRoot = Directory(root).resolveSymbolicLinksSync();
    for (final file in reports.listSync(recursive: true).whereType<File>()) {
      // Each report is named `<suite>.<runtime>.json`; every runtime writes
      // the same hit map, so a non-VM suite counts too (ADR 0020).
      if (!file.path.endsWith('.json')) continue;
      final report = jsonDecode(file.readAsStringSync());
      if (report is! Map<String, dynamic>) continue;
      for (final entry in report['coverage'] as List<dynamic>? ?? const []) {
        if (entry is! Map<String, dynamic>) continue;
        final source = entry['source'];
        final path = source is String
            ? _relative(source, packages, realRoot)
            : null;
        if (path == null) continue;
        final lines = hits.putIfAbsent(path, () => {});
        final counts = entry['hits'] as List<dynamic>? ?? const [];
        for (var i = 0; i + 1 < counts.length; i += 2) {
          final count = counts[i + 1] as int;
          lines.update(
            counts[i] as int,
            (previous) => previous + count,
            ifAbsent: () => count,
          );
        }
      }
    }
    return hits;
  }

  /// Containment-relative posix path of [source], or `null` when it is not a
  /// file inside the containment. Both sides are resolved through the
  /// filesystem: the SDK spells temp paths differently than rad created them.
  String? _relative(String source, Map<String, Uri> packages, String realRoot) {
    final uri = Uri.tryParse(source);
    final Uri? file;
    if (uri == null) {
      file = null;
    } else if (uri.scheme == 'package') {
      final segments = uri.pathSegments;
      file = segments.length < 2
          ? null
          : packages[segments.first]?.resolve(segments.skip(1).join('/'));
    } else {
      file = uri.scheme == 'file' ? uri : null;
    }
    if (file == null) return null;
    final String real;
    try {
      real = File(file.toFilePath()).resolveSymbolicLinksSync();
    } on FileSystemException {
      return null;
    }
    if (!p.isWithin(realRoot, real)) return null;
    return p.relative(real, from: realRoot).replaceAll(r'\', '/');
  }

  /// Each package's library directory, per the containment's package config.
  Map<String, Uri> _packageLibraries() {
    final file = File(p.join(root, '.dart_tool', 'package_config.json'));
    if (!file.existsSync()) return const {};
    final base = Uri.file(file.path);
    final config = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final package in config['packages'] as List<dynamic>? ?? const [])
        if (package case {
          'name': final String name,
          'rootUri': final String root,
        })
          name: base
              .resolve(_directory(root))
              .resolve(_directory(package['packageUri'] as String? ?? 'lib')),
    };
  }

  static String _directory(String uri) => uri.endsWith('/') ? uri : '$uri/';
}
