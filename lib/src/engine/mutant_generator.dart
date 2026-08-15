import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;

import '../model/mutant.dart';
import '../model/mutation.dart';
import '../mutagens/mutagen_registry.dart';
import 'mutation_visitor.dart';

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
  /// Creates a generator over [projectRoot] using [registry].
  MutantGenerator({required this.projectRoot, required this.registry});

  /// Absolute path of the project under test.
  final String projectRoot;

  /// The active mutagen set.
  final MutagenRegistry registry;

  /// All mutants, sorted by (file, offset) with stable ids (ADR 0007).
  Future<List<Mutant>> generate() async {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) return const [];

    final files =
        libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where(
              (f) => !generatedFileSuffixes.any((s) => f.path.endsWith(s)),
            )
            .map((f) => p.normalize(f.absolute.path))
            .toList()
          ..sort();

    final collection = AnalysisContextCollection(
      includedPaths: [p.normalize(libDir.absolute.path)],
    );
    final mutations = <Mutation>[];
    for (final file in files) {
      final relative = p
          .relative(file, from: p.normalize(p.absolute(projectRoot)))
          .replaceAll(r'\', '/');
      final result = await collection
          .contextFor(file)
          .currentSession
          .getResolvedUnit(file);
      if (result is! ResolvedUnitResult) continue;
      result.unit.accept(
        MutationVisitor(
          registry: registry,
          filePath: relative,
          mutations: mutations,
        ),
      );
    }

    mutations.sort((a, b) {
      final byFile = a.filePath.compareTo(b.filePath);
      if (byFile != 0) return byFile;
      final byOffset = a.offset.compareTo(b.offset);
      if (byOffset != 0) return byOffset;
      return a.operatorId.compareTo(b.operatorId);
    });

    return [
      for (final mutation in mutations)
        Mutant(
          id: '${mutation.filePath}:${mutation.offset}:${mutation.operatorId}',
          mutation: mutation,
        ),
    ];
  }
}
