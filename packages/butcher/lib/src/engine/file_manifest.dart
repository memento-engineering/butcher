import 'dart:io';

import 'package:path/path.dart' as p;

import 'mutant_generator.dart' show generatedFileSuffixes;
import 'run_aborted.dart';

/// Name of a package manifest; the lockfile beside one is always copied.
const packageManifestName = 'pubspec.yaml';

/// Name of the lockfile copied beside every package manifest, gitignored or
/// not: dropping it re-resolves every sandbox's dependencies from scratch.
const lockfileName = 'pubspec.lock';

/// Runs one `git` invocation and returns its result; the seam the tests
/// inject so parsing needs no repository.
typedef GitLister = Future<ProcessResult> Function(List<String> arguments);

/// Runs `git` with [arguments] in the current process' directory; every
/// invocation carries its own `-C` root.
Future<ProcessResult> runGit(List<String> arguments) =>
    Process.run('git', arguments);

/// Thrown when the listed root is not inside a git repository: the one
/// failure a caller answers with its own walk rather than an abort.
final class NotAGitRepository implements Exception {
  /// Names the [root] git refused to list.
  const NotAGitRepository(this.root);

  /// The root that is not a repository.
  final String root;

  @override
  String toString() => 'not a git repository: $root';
}

/// The workspace-relative posix paths a sandbox copies, taken from the
/// repository's own listing instead of a bespoke ignore dialect.
final class FileManifest {
  /// Wraps an already resolved set of workspace-relative posix [paths].
  const FileManifest(this.paths);

  /// Workspace-relative posix paths, files and symlinks alike.
  final Set<String> paths;

  /// Lists [workspaceRoot] through [lister].
  ///
  /// Throws [NotAGitRepository] when that root is outside a repository and
  /// [RunAborted] on any other git failure.
  static Future<FileManifest> of(
    String workspaceRoot, {
    GitLister lister = runGit,
  }) async {
    final listed = await _list(lister, workspaceRoot, const [
      '--cached',
      '--others',
      '--exclude-standard',
      '--deduplicate',
    ]);
    final paths = {
      ...listed,
      // A project that gitignores its generated layer would otherwise copy
      // none of it and go red on the baseline.
      ...await _list(lister, workspaceRoot, const [
        '--others',
        '--ignored',
        '--exclude-standard',
      ], [for (final suffix in generatedFileSuffixes) '*$suffix']),
    };
    for (final path in listed) {
      if (p.posix.basename(path) != packageManifestName) continue;
      final directory = p.posix.dirname(path);
      final lockfile = directory == '.'
          ? lockfileName
          : p.posix.join(directory, lockfileName);
      if (File(p.join(workspaceRoot, lockfile)).existsSync()) {
        paths.add(lockfile);
      }
    }
    return FileManifest(paths);
  }

  /// Paths listed by `git ls-files` under [options], narrowed by [pathspecs].
  ///
  /// The listing is null-separated because git quotes non-ASCII paths
  /// otherwise, and carries no `--full-name`, so its paths come out relative
  /// to [workspaceRoot] even when that root sits inside a larger repository.
  static Future<Set<String>> _list(
    GitLister lister,
    String workspaceRoot,
    List<String> options, [
    List<String> pathspecs = const [],
  ]) async {
    final result = await lister([
      '-C',
      workspaceRoot,
      'ls-files',
      ...options,
      '-z',
      if (pathspecs.isNotEmpty) ...['--', ...pathspecs],
    ]);
    if (result.exitCode != 0) {
      final error = '${result.stderr}';
      if (error.contains('not a git repository')) {
        throw NotAGitRepository(workspaceRoot);
      }
      throw RunAborted('git ls-files failed in $workspaceRoot: $error');
    }
    return {
      for (final path in '${result.stdout}'.split('\u0000'))
        if (path.isNotEmpty) path,
    };
  }
}
