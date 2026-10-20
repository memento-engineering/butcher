import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'run_aborted.dart';

/// The pub workspace members a selected package can reach, and those it
/// cannot, so a sandbox need not copy the unreachable ones.
final class WorkspaceClosure {
  WorkspaceClosure._(this.kept, this.dropped);

  /// Workspace-relative posix directories of the reachable members.
  final Set<String> kept;

  /// Workspace-relative posix directories of the unreachable members.
  final Set<String> dropped;

  /// Walks the members of the workspace at [workspaceRoot] from the one at
  /// [projectRoot] and from the root manifest, following every dependency,
  /// dev dependency and override that names a member: pub resolves the dev
  /// dependencies of every member it keeps.
  static Future<WorkspaceClosure> resolve(
    String workspaceRoot,
    String projectRoot,
  ) async {
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
    // pub lists resolved paths, so the roots are resolved to match them.
    final root = Directory(workspaceRoot).resolveSymbolicLinksSync();
    final project = Directory(projectRoot).resolveSymbolicLinksSync();
    final listed = (jsonDecode('${result.stdout}') as Map)['packages'] as List;
    final members = {
      for (final member in listed.cast<Map<dynamic, dynamic>>())
        member['name'] as String: p
            .relative(member['path'] as String, from: root)
            .replaceAll(r'\', '/'),
    };
    final target = p.relative(project, from: root).replaceAll(r'\', '/');
    final reached = <String>{};
    final pending = [
      for (final entry in members.entries)
        if (entry.value == '.' || entry.value == target) entry.key,
    ];
    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      if (!reached.add(name)) continue;
      pending.addAll(
        _dependencies(
          p.join(workspaceRoot, members[name]!),
        ).where(members.containsKey),
      );
    }
    return WorkspaceClosure._(
      {for (final name in reached) members[name]!},
      {
        for (final entry in members.entries)
          if (!reached.contains(entry.key)) entry.value,
      },
    );
  }

  static Iterable<String> _dependencies(String memberRoot) sync* {
    final manifest = loadYaml(
      File(p.join(memberRoot, 'pubspec.yaml')).readAsStringSync(),
    );
    if (manifest is! YamlMap) return;
    for (final key in [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ]) {
      final section = manifest[key];
      if (section is YamlMap) yield* section.keys.cast<String>();
    }
  }

  /// Whether the workspace-relative posix [path] lies in a dropped member
  /// and in no kept one nested inside it.
  bool excludes(String path) =>
      dropped.any((member) => _inside(member, path)) &&
      !kept.any((member) => member != '.' && _inside(member, path));

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
    return source.replaceRange(
      workspace.span.start.offset,
      workspace.span.end.offset,
      '[${members.join(', ')}]',
    );
  }
}
