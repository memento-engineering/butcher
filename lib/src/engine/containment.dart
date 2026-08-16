import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/mutation.dart';
import '../rad_paths.dart';
import 'rad_ignore.dart';

/// Directories never copied into a containment (ADR 0004).
const defaultContainmentExcludes = ['.git', '.dart_tool', 'build', 'coverage'];

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

  /// Copies [projectRoot] into a fresh temp dir, honoring exclusions; a
  /// missing [ignore] loads the project's `.radignore`.
  static Future<Containment> create(
    String projectRoot, {
    required RadPaths paths,
    RadIgnore? ignore,
  }) async {
    final source = p.normalize(p.absolute(projectRoot));
    final tempRoot = Directory(paths.root)..createSync(recursive: true);
    final target = await tempRoot.createTemp(containmentPrefix);
    final exclusions = ignore ?? RadIgnore.load(source);

    await for (final entity in Directory(
      source,
    ).list(recursive: true, followLinks: false)) {
      final relative = p
          .relative(entity.path, from: source)
          .replaceAll(r'\', '/');
      if (_excluded(relative, entity is Directory, exclusions)) continue;
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

  static bool _excluded(String relative, bool isDirectory, RadIgnore ignore) {
    if (defaultContainmentExcludes.contains(p.posix.split(relative).first)) {
      return true;
    }
    return ignore.excludes(relative, isDirectory: isDirectory);
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
