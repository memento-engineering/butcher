import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;

import '../model/mutant.dart';
import '../model/mutation.dart';
import '../mutagens/mutagen_registry.dart';
import 'mutation_visitor.dart';
import 'rad_ignore.dart';

/// Suffixes of generated files never irradiated.
const generatedFileSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.pb.dart',
  '.pbenum.dart',
  '.pbjson.dart',
  '.pbserver.dart',
  '.mocks.dart',
];

/// Enumerates mutants for a project's `lib/` via one resolved AST walk.
final class MutantGenerator {
  /// Creates a generator over [projectRoot] using [registry], skipping what
  /// [ignore] excludes.
  MutantGenerator({
    required this.projectRoot,
    required this.registry,
    required this.ignore,
  });

  /// Absolute path of the project under test.
  final String projectRoot;

  /// The active mutagen set.
  final MutagenRegistry registry;

  /// Consumer exclusions shared with containment (ADR 0004).
  final RadIgnore ignore;

  /// All mutants, sorted with stable ids (ADR 0007), plus the pristine
  /// source per irradiated file so reports stay aligned even when the
  /// working tree changes mid-run.
  Future<(List<Mutant>, Map<String, String>)> generate() async {
    final sources = <String, String>{};
    final root = p.normalize(p.absolute(projectRoot));
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) return (const <Mutant>[], sources);

    final files =
        libDir
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !generatedFileSuffixes.any((s) => f.path.endsWith(s)))
            .map((f) => p.normalize(f.absolute.path))
            .map((f) => (f, p.relative(f, from: root).replaceAll(r'\', '/')))
            .where((f) => !ignore.excludes(f.$2, isDirectory: false))
            .toList()
          ..sort((a, b) => a.$1.compareTo(b.$1));

    final collection = AnalysisContextCollection(
      includedPaths: [p.normalize(libDir.absolute.path)],
    );
    final mutations = <Mutation>[];
    for (final (file, relative) in files) {
      final result = await collection
          .contextFor(file)
          .currentSession
          .getResolvedUnit(file);
      if (result is! ResolvedUnitResult) continue;
      sources[relative] = result.content;
      result.unit.accept(
        MutationVisitor(
          registry: registry,
          filePath: relative,
          source: result.content,
          mutations: mutations,
        ),
      );
    }

    mutations.sort((a, b) {
      final byFile = a.filePath.compareTo(b.filePath);
      if (byFile != 0) return byFile;
      final byOffset = a.offset.compareTo(b.offset);
      if (byOffset != 0) return byOffset;
      final byOperator = a.operatorId.compareTo(b.operatorId);
      if (byOperator != 0) return byOperator;
      return a.replacement.compareTo(b.replacement);
    });

    final mutants = [
      for (final mutation in mutations)
        Mutant(
          id:
              '${mutation.filePath}:${mutation.offset}'
              ':${mutation.operatorId}:${mutation.replacement}',
          mutation: mutation,
        ),
    ];
    return (mutants, sources);
  }
}
