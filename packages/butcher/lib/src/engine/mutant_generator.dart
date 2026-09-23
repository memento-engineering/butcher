import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;

import '../config/mutation_scope.dart';
import '../model/mutant.dart';
import '../model/mutation.dart';
import '../mutators/mutator_registry.dart';
import 'sandbox.dart';
import 'mutation_visitor.dart';
import 'project_analysis.dart';

/// Suffixes of generated files never mutated.
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
  /// Creates a generator over [projectRoot] using [registry], skipping every
  /// path [isExcluded] rejects.
  MutantGenerator({
    required this.projectRoot,
    required this.registry,
    required this.isExcluded,
  });

  /// Absolute path of the project under test.
  final String projectRoot;

  /// The active mutator set.
  final MutatorRegistry registry;

  /// Consumer exclusions from `butcher.yaml` (ADR 0004).
  final MutationExclusion isExcluded;

  /// Analyzer state the viability check reuses (ADR 0019).
  late final analysis = ProjectAnalysis(projectRoot: projectRoot);

  /// All mutants, sorted with stable ids (ADR 0007), plus the pristine
  /// source per mutated file so reports stay aligned even when the
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
            .where(
              (f) => !p.posix.split(f.$2).any(toolingSandboxExcludes.contains),
            )
            .where((f) => !isExcluded(f.$2))
            .toList()
          ..sort((a, b) => a.$1.compareTo(b.$1));

    final mutations = <Mutation>[];
    for (final (file, relative) in files) {
      final result = await analysis.collection
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
      final byOperator = a.mutatorId.compareTo(b.mutatorId);
      if (byOperator != 0) return byOperator;
      return a.replacement.compareTo(b.replacement);
    });

    final mutants = [
      for (final mutation in mutations)
        Mutant(
          id:
              '${mutation.filePath}:${mutation.offset}'
              ':${mutation.mutatorId}:${mutation.replacement}',
          mutation: mutation,
        ),
    ];
    return (mutants, sources);
  }
}
