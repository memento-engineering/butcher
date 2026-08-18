import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

/// One analyzer context collection over a project's `lib/`, shared by mutant
/// generation and the viability check (ADR 0019) so a file resolved once
/// stays resolved.
///
/// The overlay provider lets the viability check swap mutated sources in
/// memory without touching the working tree.
final class ProjectAnalysis {
  /// Creates the analysis state for the project at [projectRoot].
  ProjectAnalysis({required this.projectRoot});

  /// Absolute or relative path of the project under test.
  final String projectRoot;

  /// Serves mutated sources in place of their files while an overlay is set.
  final provider = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);

  /// Built on first use so projects without `lib/` never construct it.
  late final collection = AnalysisContextCollection(
    includedPaths: [absolutePath('lib')],
    resourceProvider: provider,
  );

  /// The absolute, normalized path of [relative] within the project.
  String absolutePath(String relative) =>
      p.normalize(p.absolute(projectRoot, relative));
}
