import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/mutation.dart';
import '../butcher_paths.dart';
import 'rad_ignore.dart';

/// Top-level output directories never copied into a sandbox (ADR 0004).
const defaultSandboxExcludes = ['build', 'coverage'];

/// Tooling artefacts never copied, at any depth; generation skips the same
/// names so the two exclusion sets cannot desync (ADR 0004).
const toolingSandboxExcludes = ['.git', '.dart_tool'];

/// Prefix of every sandbox directory; startup cleanup matches on it.
const sandboxPrefix = 'sandbox_';

/// A filtered temp-dir copy of the workspace around a selected project.
final class Sandbox {
  Sandbox._(this.root, this.projectRoot);

  /// Absolute path of the copied workspace root.
  final String root;

  /// Absolute path of the selected package inside this sandbox.
  final String projectRoot;

  /// Random directory name of this sandbox; names its run log (ADR 0016).
  String get name => p.basename(root);

  final Map<String, String> _pristine = {};

  /// Copies [workspaceRoot], or [projectRoot] when absent, into a fresh temp
  /// dir. [workspaceIgnore] applies workspace-relative rules while [ignore]
  /// remains relative to the selected project.
  static Future<Sandbox> create(
    String projectRoot, {
    required ButcherPaths paths,
    required RadIgnore ignore,
    String? workspaceRoot,
    RadIgnore? workspaceIgnore,
  }) async {
    final project = p.normalize(p.absolute(projectRoot));
    final source = p.normalize(p.absolute(workspaceRoot ?? project));
    if (!p.equals(source, project) && !p.isWithin(source, project)) {
      throw ArgumentError.value(
        projectRoot,
        'projectRoot',
        'must be inside workspaceRoot $source',
      );
    }
    final projectRelative = p.relative(project, from: source);
    final tempRoot = Directory(paths.root)..createSync(recursive: true);
    final target = await tempRoot.createTemp(sandboxPrefix);
    // An in-project rad root must never copy itself (recursive growth); a
    // rad root at or above the project only prunes the fresh target.
    final prune = p.isWithin(source, paths.root) ? paths.root : target.path;

    await _copyInto(Directory(source), target.path, '', (
      entity,
      name,
      relative,
    ) {
      if (p.equals(prune, entity.path)) return true;
      final memberRelative = p.equals(project, entity.path)
          ? ''
          : p.isWithin(project, entity.path)
          ? p.relative(entity.path, from: project).replaceAll(r'\', '/')
          : null;
      return _excluded(
        name,
        relative,
        memberRelative,
        entity is Directory,
        ignore,
        workspaceIgnore,
      );
    });
    return Sandbox._(
      target.path,
      projectRelative == '.'
          ? target.path
          : p.join(target.path, projectRelative),
    );
  }

  /// Copies this sandbox, resolved dependencies included, into a fresh
  /// independent one so `dart pub get` runs once per run instead of once per
  /// worker (ADR 0017).
  Future<Sandbox> clone() async {
    final target = await Directory(p.dirname(root)).createTemp(sandboxPrefix);
    await _copyInto(Directory(root), target.path, '', (_, _, _) => false);
    return Sandbox._(
      target.path,
      p.join(target.path, p.relative(projectRoot, from: root)),
    );
  }

  /// Recurses [source] into [destination], [prefix] being the source-relative
  /// posix path of [source]; entities matching [skip] are never copied and
  /// directories among them are never descended into. [skip] receives each
  /// entity's own name and its source-relative posix path.
  static Future<void> _copyInto(
    Directory source,
    String destination,
    String prefix,
    bool Function(FileSystemEntity entity, String name, String relative) skip,
  ) async {
    await Directory(destination).create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final relative = prefix.isEmpty ? name : '$prefix/$name';
      if (skip(entity, name, relative)) continue;
      final target = p.join(destination, name);
      if (entity is Directory) {
        await _copyInto(entity, target, relative, skip);
      } else if (entity is File) {
        await entity.copy(target);
      }
    }
  }

  /// Whether an entity stays out of the copy under workspace and project
  /// scopes. The walk is hierarchical, so excluded directories are pruned.
  static bool _excluded(
    String name,
    String workspaceRelative,
    String? projectRelative,
    bool isDirectory,
    RadIgnore ignore,
    RadIgnore? workspaceIgnore,
  ) {
    if (toolingSandboxExcludes.contains(name) ||
        ((workspaceRelative == name || projectRelative == name) &&
            defaultSandboxExcludes.contains(name))) {
      return true;
    }
    return (workspaceIgnore?.excludes(
              workspaceRelative,
              isDirectory: isDirectory,
            ) ??
            false) ||
        (projectRelative != null &&
            projectRelative.isNotEmpty &&
            ignore.excludes(projectRelative, isDirectory: isDirectory));
  }

  /// Applies [mutation] to its file; [restore] undoes it.
  Future<void> apply(Mutation mutation) async {
    final file = File(p.join(projectRoot, mutation.filePath));
    final content = await file.readAsString();
    _pristine[mutation.filePath] = content;
    final end = mutation.offset + mutation.length;
    if (end > content.length) {
      throw StateError(
        'sandbox drift in ${mutation.filePath}@${mutation.offset}: '
        'expected "${mutation.original}", file ends at ${content.length}',
      );
    }
    final found = content.substring(mutation.offset, end);
    if (found != mutation.original) {
      throw StateError(
        'sandbox drift in ${mutation.filePath}@${mutation.offset}: '
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
    await File(p.join(projectRoot, filePath)).writeAsString(pristine);
  }
}
