import '../engine/file_manifest.dart';

/// Project-relative posix paths of the `lib/` files changed since [ref].
///
/// The working tree is compared against [ref], so uncommitted edits count,
/// and untracked files that are not ignored count as changed. Deleted files
/// drop out: there is nothing left to mutate.
///
/// Throws a [FormatException] when git cannot resolve [ref] or [projectRoot]
/// is not inside a repository.
Future<Set<String>> diffScope(
  String projectRoot,
  String ref, {
  GitLister lister = runGit,
}) async {
  Future<Iterable<String>> paths(List<String> arguments) async {
    final result = await lister([
      '-C',
      projectRoot,
      ...arguments,
      '-z',
      '--',
      'lib/',
    ]);
    if (result.exitCode != 0) {
      throw FormatException(
        '--diff-base $ref cannot be resolved: ${'${result.stderr}'.trim()}',
      );
    }
    return '${result.stdout}'.split('\u0000').where((p) => p.isNotEmpty);
  }

  return {
    ...await paths([
      'diff',
      '--name-only',
      '--relative',
      '--diff-filter=d',
      ref,
    ]),
    ...await paths(['ls-files', '--others', '--exclude-standard']),
  };
}
