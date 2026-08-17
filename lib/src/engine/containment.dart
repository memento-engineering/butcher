import 'dart:io';

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../model/mutation.dart';
import '../rad_paths.dart';

/// Directories never copied into a containment (ADR 0004).
const defaultContainmentExcludes = ['.git', '.dart_tool', 'build', 'coverage'];

/// Name of the consumer exclusion file, gitignore-style, at the project root.
const containmentIgnoreFile = '.radignore';

/// Prefix of every containment directory; startup cleanup matches on it.
const containmentPrefix = 'containment_';

/// A filtered temp-dir copy of the project; all irradiation happens here.
final class Containment {
  Containment._(this.root);

  /// Absolute path of the copied project root.
  final String root;

  /// Random directory name of this containment; names its run log (ADR 0016).
  String get name => p.basename(root);

  final Map<String, String> _pristine = {};

  /// Copies [projectRoot] into a fresh temp dir, honoring exclusions.
  static Future<Containment> create(
    String projectRoot, {
    required RadPaths paths,
  }) async {
    final source = p.normalize(p.absolute(projectRoot));
    final tempRoot = Directory(paths.root)..createSync(recursive: true);
    final target = await tempRoot.createTemp(containmentPrefix);
    final globs = _consumerGlobs(source);

    await for (final entity in Directory(
      source,
    ).list(recursive: true, followLinks: false)) {
      final relative = p
          .relative(entity.path, from: source)
          .replaceAll(r'\', '/');
      if (_excluded(relative, globs)) continue;
      final destination = p.join(target.path, relative);
      if (entity is Directory) {
        Directory(destination).createSync(recursive: true);
      } else if (entity is File) {
        Directory(p.dirname(destination)).createSync(recursive: true);
        entity.copySync(destination);
      }
    }
    return Containment._(target.path);
  }

  static List<Glob> _consumerGlobs(String source) {
    final file = File(p.join(source, containmentIgnoreFile));
    if (!file.existsSync()) return const [];
    return file
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .map(Glob.new)
        .toList();
  }

  static bool _excluded(String relative, List<Glob> globs) {
    final segments = p.posix.split(relative);
    if (defaultContainmentExcludes.contains(segments.first)) return true;
    return globs.any((glob) => glob.matches(relative));
  }

  /// Applies [mutation] to its file; [restore] undoes it.
  Future<void> apply(Mutation mutation) async {
    final file = File(p.join(root, mutation.filePath));
    final content = await file.readAsString();
    _pristine[mutation.filePath] = content;
    final end = mutation.offset + mutation.length;
    if (end > content.length) {
      throw StateError(
        'containment drift in ${mutation.filePath}@${mutation.offset}: '
        'expected "${mutation.original}", file ends at ${content.length}',
      );
    }
    final found = content.substring(mutation.offset, end);
    if (found != mutation.original) {
      throw StateError(
        'containment drift in ${mutation.filePath}@${mutation.offset}: '
        'expected "${mutation.original}", found "$found"',
      );
    }
    await file.writeAsString(
      content.replaceRange(mutation.offset, end, mutation.replacement),
    );
  }

  /// Restores the pristine content of [filePath] after [apply].
  Future<void> restore(String filePath) async {
    final pristine = _pristine.remove(filePath);
    if (pristine == null) return;
    await File(p.join(root, filePath)).writeAsString(pristine);
  }
}
