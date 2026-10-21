import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'file_manifest.dart';
import 'run_aborted.dart';

/// The pub workspace members a selected package can reach, and those it
/// cannot, so a sandbox need not copy the unreachable ones.
final class WorkspaceClosure {
  WorkspaceClosure._(this.kept, this.dropped, this._protected);

  /// Workspace-relative posix directories of the reachable members.
  final Set<String> kept;

  /// Workspace-relative posix directories of the unreachable members and of
  /// the other packages no kept one depends on by path.
  final Set<String> dropped;

  /// Kept members and the packages they reach by path, copied even inside a
  /// dropped directory.
  final Set<String> _protected;

  /// Walks the members of the workspace at [workspaceRoot] from the one at
  /// [projectRoot] and from the root manifest, following every dependency,
  /// dev dependency and override that names a member: pub resolves the dev
  /// dependencies of every member it keeps.
  ///
  /// Every other package directory in the git listing, a nested workspace
  /// root included, is dropped unless a kept package reaches it by path.
  static Future<WorkspaceClosure> resolve(
    String workspaceRoot,
    String projectRoot, {
    GitLister lister = runGit,
  }) async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'pub',
      'workspace',
      'list',
      '--json',
    ], workingDirectory: workspaceRoot);
    if (result.exitCode != 0) {
      throw RunAborted(
        'pub workspace list failed in $workspaceRoot:\n'
        '${result.stdout}${result.stderr}',
      );
    }
    // Members are matched by name and relativized against pub's own path for
    // the root: pub prints resolved long paths, which need not match the
    // spelling of the roots given here (a symlinked or 8.3 short temp dir).
    final listed = {
      for (final member
          in ((jsonDecode('${result.stdout}') as Map)['packages'] as List)
              .cast<Map<dynamic, dynamic>>())
        member['name'] as String: member['path'] as String,
    };
    final rootName = _name(workspaceRoot);
    final members = {
      for (final entry in listed.entries)
        entry.key: p
            .relative(entry.value, from: listed[rootName])
            .replaceAll(r'\', '/'),
    };
    final reached = <String>{};
    final pending = [rootName, _name(projectRoot)];
    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      if (!reached.add(name)) continue;
      pending.addAll(
        _dependencies(
          p.join(workspaceRoot, members[name]!),
        ).keys.where(members.containsKey),
      );
    }
    final kept = {for (final name in reached) members[name]!};
    final protected = {
      ...kept.where((member) => member != '.'),
      ..._pathed(workspaceRoot, kept),
    };
    final dropped = {
      for (final entry in members.entries)
        if (!reached.contains(entry.key)) entry.value,
    };
    final memberDirs = members.values.toSet();
    // Sorted, so a nested workspace's own members fold into its root.
    for (final package in [...await _packages(workspaceRoot, lister)]..sort()) {
      if (memberDirs.contains(package) ||
          [...protected, ...dropped].any((dir) => _inside(dir, package))) {
        continue;
      }
      dropped.add(package);
    }
    return WorkspaceClosure._(kept, dropped, protected);
  }

  static Object? _manifest(String packageRoot) {
    final file = File(p.join(packageRoot, packageManifestName));
    return file.existsSync() ? loadYaml(file.readAsStringSync()) : null;
  }

  static String _name(String packageRoot) =>
      (_manifest(packageRoot) as YamlMap)['name'] as String;

  static Map<String, Object?> _dependencies(String packageRoot) {
    final manifest = _manifest(packageRoot);
    if (manifest is! YamlMap) return const {};
    return {
      for (final key in [
        'dependencies',
        'dev_dependencies',
        'dependency_overrides',
      ])
        if (manifest[key] case final YamlMap section)
          for (final entry in section.entries) entry.key as String: entry.value,
    };
  }

  /// Workspace-relative directories [from] reaches through path
  /// dependencies, transitively.
  static Set<String> _pathed(String workspaceRoot, Iterable<String> from) {
    final found = <String>{};
    final pending = [...from];
    while (pending.isNotEmpty) {
      final dir = pending.removeLast();
      for (final source in _dependencies(p.join(workspaceRoot, dir)).values) {
        if (source case {'path': final String path}) {
          final relative = p
              .relative(
                p.normalize(p.join(workspaceRoot, dir, path)),
                from: workspaceRoot,
              )
              .replaceAll(r'\', '/');
          if (relative == '.' || relative.startsWith('..')) continue;
          if (found.add(relative)) pending.add(relative);
        }
      }
    }
    return found;
  }

  /// Directories other than the root holding a listed package manifest;
  /// none outside a git repository.
  static Future<Set<String>> _packages(
    String workspaceRoot,
    GitLister lister,
  ) async {
    try {
      final manifest = await FileManifest.of(workspaceRoot, lister: lister);
      return {
        for (final path in manifest.paths)
          if (p.posix.basename(path) == packageManifestName &&
              path != packageManifestName)
            p.posix.dirname(path),
      };
    } on NotAGitRepository {
      return const {};
    }
  }

  /// Whether the workspace-relative posix [path] lies in a dropped directory
  /// and in no kept one nested inside it.
  bool excludes(String path) =>
      dropped.any((dir) => _inside(dir, path)) &&
      !_protected.any((dir) => _inside(dir, path));

  static bool _inside(String member, String path) =>
      member == path || p.posix.isWithin(member, path);

  /// The root manifest [source] with its `workspace:` list narrowed to the
  /// kept members.
  String trim(String source) {
    final workspace = (loadYaml(source) as YamlMap).nodes['workspace'];
    if (workspace == null) return source;
    final members = [
      for (final member in kept.toList()..sort())
        if (member != '.') jsonEncode(member),
    ];
    // A block list's span runs up to the next key, line breaks included.
    final text = workspace.span.text;
    return source.replaceRange(
      workspace.span.start.offset,
      workspace.span.end.offset,
      '[${members.join(', ')}]${text.substring(text.trimRight().length)}',
    );
  }
}
