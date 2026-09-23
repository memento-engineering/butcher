import 'dart:io';

import 'package:path/path.dart' as p;

import '../log/butcher_logger.dart';
import '../model/mutation.dart';
import '../butcher_paths.dart';
import 'file_manifest.dart';

/// Top-level output directories never copied into a sandbox (ADR 0004).
const defaultSandboxExcludes = ['build', 'coverage'];

/// Tooling artefacts never copied, at any depth; generation skips the same
/// names so the two exclusion sets cannot desync (ADR 0004).
const toolingSandboxExcludes = ['.git', '.dart_tool'];

/// Prefix of every sandbox directory; startup cleanup matches on it.
const sandboxPrefix = 'sandbox_';

/// A temp-dir copy of the workspace around a selected project, holding the
/// files the repository's own git listing names.
final class Sandbox {
  Sandbox._(this.root, this.projectRoot, this._copied);

  /// Absolute path of the copied workspace root.
  final String root;

  /// Absolute path of the selected package inside this sandbox.
  final String projectRoot;

  /// Root-relative posix path of everything copied into this sandbox; a
  /// clone copies the same set instead of walking the tree again.
  final Set<String> _copied;

  /// Random directory name of this sandbox; names its run log (ADR 0016).
  String get name => p.basename(root);

  final Map<String, String> _pristine = {};

  /// Copies [workspaceRoot], or [projectRoot] when absent, into a fresh temp
  /// dir. The copy set is the workspace's git listing, so the repository's
  /// own ignore rules decide it; a root outside a repository falls back to a
  /// walk under the built-in exclusions alone.
  static Future<Sandbox> create(
    String projectRoot, {
    required ButcherPaths paths,
    String? workspaceRoot,
    ButcherLogger? logger,
    GitLister lister = runGit,
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
    // An in-project butcher root must never copy itself (recursive growth); a
    // butcher root at or above the project only prunes the fresh target.
    final prune = p.isWithin(source, paths.root) ? paths.root : target.path;

    final copied = await _copySource(
      source,
      target.path,
      project,
      prune,
      logger,
      lister,
    );
    return Sandbox._(
      target.path,
      projectRelative == '.'
          ? target.path
          : p.join(target.path, projectRelative),
      copied,
    );
  }

  /// Copies [source] into [destination] under the repository's listing, or
  /// under the built-in exclusions alone when it is not a repository.
  static Future<Set<String>> _copySource(
    String source,
    String destination,
    String project,
    String prune,
    ButcherLogger? logger,
    GitLister lister,
  ) async {
    try {
      final manifest = await FileManifest.of(source, lister: lister);
      return await _copyPaths(source, destination, [
        for (final relative in manifest.paths.toList()..sort())
          if (!_pruned(source, relative, prune) &&
              !_excluded(relative, source, project))
            relative,
      ], logger);
    } on NotAGitRepository {
      logger?.info(
        'copying {WorkspaceRoot} with the built-in exclusions only: '
        'it is not a git repository',
        {'WorkspaceRoot': source},
      );
      return _copyWalk(source, destination, project, prune);
    }
  }

  /// Copies this sandbox, resolved dependencies included, into a fresh
  /// independent one so `dart pub get` runs once per run instead of once per
  /// worker (ADR 0017).
  Future<Sandbox> clone() async {
    final target = await Directory(p.dirname(root)).createTemp(sandboxPrefix);
    final copied = await _copyPaths(root, target.path, [
      ..._copied,
      ..._resolved(),
    ], null);
    return Sandbox._(
      target.path,
      p.join(target.path, p.relative(projectRoot, from: root)),
      copied,
    );
  }

  /// What `dart pub get` left in this sandbox: the tooling directories and
  /// lockfiles a worker inherits rather than resolves for itself.
  Iterable<String> _resolved() sync* {
    for (final entity in Directory(
      root,
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p
          .relative(entity.path, from: root)
          .replaceAll(r'\', '/');
      final segments = p.posix.split(relative);
      if (segments.contains('.dart_tool') || segments.last == lockfileName) {
        yield relative;
      }
    }
  }

  /// Copies each of [relatives], a [source]-relative posix path, under
  /// [destination]; returns the ones that landed there.
  static Future<Set<String>> _copyPaths(
    String source,
    String destination,
    Iterable<String> relatives,
    ButcherLogger? logger,
  ) async {
    await Directory(destination).create(recursive: true);
    final copied = <String>{};
    final created = <String>{};
    for (final relative in relatives) {
      final segments = p.posix.split(relative);
      final origin = p.join(source, p.joinAll(segments));
      final target = p.join(destination, p.joinAll(segments));
      final parent = p.dirname(target);
      if (created.add(parent)) await Directory(parent).create(recursive: true);
      if (FileSystemEntity.isLinkSync(origin)) {
        if (!await _copyLink(origin, target, source, logger)) continue;
      } else {
        final file = File(origin);
        if (!file.existsSync()) continue;
        await file.copy(target);
      }
      copied.add(relative);
    }
    return copied;
  }

  /// Recreates the symlink at [origin] under [target] with its recorded
  /// target, unless that target resolves outside [source].
  static Future<bool> _copyLink(
    String origin,
    String target,
    String source,
    ButcherLogger? logger,
  ) async {
    final linkTarget = Link(origin).targetSync();
    final resolved = p.normalize(
      p.isAbsolute(linkTarget)
          ? linkTarget
          : p.join(p.dirname(origin), linkTarget),
    );
    if (!p.equals(source, resolved) && !p.isWithin(source, resolved)) {
      logger?.info(
        'skipped symlink {Link}: its target {Target} resolves outside the '
        'workspace',
        {'Link': origin, 'Target': resolved},
      );
      return false;
    }
    // Git always records a relative link target with posix separators; the
    // filesystem's symlink API takes that string verbatim rather than
    // parsing it as a path, so on Windows a target still carrying `/`
    // creates a link nothing can resolve. Nativize it before recreating.
    final recreateTarget = p.isAbsolute(linkTarget)
        ? linkTarget
        : p.joinAll(p.posix.split(linkTarget));
    await Link(target).create(recreateTarget);
    return true;
  }

  /// Hierarchical fallback for a [source] outside a repository: the built-in
  /// exclusions alone, excluded directories never descended into.
  static Future<Set<String>> _copyWalk(
    String source,
    String destination,
    String project,
    String prune,
  ) async {
    final copied = <String>{};
    await _copyInto(
      Directory(source),
      destination,
      '',
      copied,
      (entity, relative) =>
          p.equals(prune, entity.path) || _excluded(relative, source, project),
    );
    return copied;
  }

  /// Recurses [source] into [destination], [prefix] being the source-relative
  /// posix path of [source]; entities matching [skip] are never copied and
  /// directories among them are never descended into. Every copied file's
  /// source-relative posix path lands in [copied].
  static Future<void> _copyInto(
    Directory source,
    String destination,
    String prefix,
    Set<String> copied,
    bool Function(FileSystemEntity entity, String relative) skip,
  ) async {
    await Directory(destination).create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final relative = prefix.isEmpty ? name : '$prefix/$name';
      if (skip(entity, relative)) continue;
      final target = p.join(destination, name);
      if (entity is Directory) {
        await _copyInto(entity, target, relative, copied, skip);
      } else if (entity is File) {
        await entity.copy(target);
        copied.add(relative);
      }
    }
  }

  /// Whether the [source]-relative posix path [relative] is the butcher temp
  /// root being written into, or lives inside it.
  static bool _pruned(String source, String relative, String prune) {
    final entity = p.join(source, p.joinAll(p.posix.split(relative)));
    return p.equals(prune, entity) || p.isWithin(prune, entity);
  }

  /// Whether the [source]-relative posix path [relative] stays out of the
  /// copy under the two built-in exclusion sets, in workspace scope and in
  /// the selected [project]'s own scope.
  static bool _excluded(String relative, String source, String project) {
    final segments = p.posix.split(relative);
    if (segments.any(toolingSandboxExcludes.contains)) return true;
    if (defaultSandboxExcludes.contains(segments.first)) return true;
    if (p.equals(source, project)) return false;
    final member = p.relative(project, from: source).replaceAll(r'\', '/');
    if (!p.posix.isWithin(member, relative)) return false;
    return defaultSandboxExcludes.contains(
      p.posix.split(p.posix.relative(relative, from: member)).first,
    );
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
