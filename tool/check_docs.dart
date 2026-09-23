/// Asserts that the documentation tree hangs together.
///
/// A shell grep can prove a word is gone; it cannot resolve a markdown link or
/// reconcile an index against the files on disk. These checks walk `docs/`,
/// resolve every relative link target, reconcile the decision index against the
/// entry files beside it in both directions, and assert that the retired entry
/// still declares itself retired.
///
/// Run from the repository root:
///
/// ```
/// dart run tool/check_docs.dart
/// ```
///
/// Exits 0 when every check passes, or 1 with a report naming each violation.
library;

import 'dart:io';

const _docsDir = 'docs';
const _decisionsDir = '$_docsDir/decisions';
const _decisionsIndex = '$_decisionsDir/views/index.md';
const _retiredEntrySuffix = '-naming-and-vocabulary.md';

/// Raised by a check that its subject violates, carrying the operator-readable
/// reasons.
class CheckFailure implements Exception {
  /// Creates a failure reported under [check] for [reasons].
  CheckFailure(this.check, this.reasons);

  /// The name of the check that failed.
  final String check;

  /// Why it failed, in terms an operator can act on; one entry per violation.
  final List<String> reasons;

  @override
  String toString() => '$check: ${reasons.join('; ')}';
}

/// One named assertion over the documentation tree.
typedef Check = ({String name, void Function() run});

void main() {
  final checks = <Check>[
    (name: 'every relative link under docs resolves', run: _checkLinks),
    (name: 'the decision index matches the entries on disk', run: _checkIndex),
    (name: 'the naming entry is retired', run: _checkRetiredEntry),
  ];

  var failed = false;
  for (final check in checks) {
    try {
      check.run();
    } on CheckFailure catch (failure) {
      stderr.writeln('check_docs: FAILED - ${failure.check}');
      for (final reason in failure.reasons) {
        stderr.writeln('  $reason');
      }
      failed = true;
      continue;
    }
    stdout.writeln('check_docs: ok - ${check.name}');
  }

  if (failed) {
    exitCode = 1;
    return;
  }

  stdout.writeln('check_docs: ${checks.length} checks passed');
}

/// Every markdown file under `docs/`, in a stable order.
List<File> _markdownFiles() {
  final root = Directory(_docsDir);
  if (!root.existsSync()) {
    throw CheckFailure('every relative link under docs resolves', [
      'no such directory: $_docsDir',
    ]);
  }

  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.md'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// A markdown link found in a source file.
typedef Link = ({String file, int line, String target});

/// The inline-link pattern; the label may itself contain balanced brackets, so
/// the label is matched lazily and the target is anything up to the closing
/// parenthesis.
final _linkPattern = RegExp(r'!?\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)');

/// Reads [file] and returns its links, ignoring fenced code blocks: a diagram
/// fence carries bracket-and-parenthesis shapes that are not links.
List<Link> _linksIn(File file) {
  final links = <Link>[];
  var fenced = false;

  final lines = file.readAsLinesSync();
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    if (line.trimLeft().startsWith('```')) {
      fenced = !fenced;
      continue;
    }
    if (fenced) continue;

    for (final match in _linkPattern.allMatches(line)) {
      links.add((file: file.path, line: index + 1, target: match.group(1)!));
    }
  }

  return links;
}

/// Whether [target] points outside the tree and so cannot be resolved here.
bool _isExternal(String target) =>
    target.startsWith('http://') ||
    target.startsWith('https://') ||
    target.startsWith('mailto:') ||
    target.startsWith('#');

/// The path a relative [target] resolves to, relative to the repository root.
String _resolve(String fromFile, String target) {
  final withoutAnchor = target.split('#').first;
  final base = Uri.file(fromFile).resolve(withoutAnchor);
  final resolved = base.toFilePath();
  final root = '${Directory.current.path}${Platform.pathSeparator}';
  return resolved.startsWith(root) ? resolved.substring(root.length) : resolved;
}

void _checkLinks() {
  const check = 'every relative link under docs resolves';

  final broken = <String>[];
  for (final file in _markdownFiles()) {
    for (final link in _linksIn(file)) {
      if (_isExternal(link.target)) continue;

      final path = _resolve(link.file, link.target);
      if (path.isEmpty) continue;

      final exists =
          File(path).existsSync() ||
          Directory(path).existsSync() ||
          // A directory target written with a trailing separator.
          Directory(
            path.endsWith(Platform.pathSeparator)
                ? path.substring(0, path.length - 1)
                : path,
          ).existsSync();

      if (!exists) {
        broken.add(
          '${link.file}:${link.line} links to ${link.target}, which resolves '
          'to $path and does not exist',
        );
      }
    }
  }

  if (broken.isNotEmpty) throw CheckFailure(check, broken);
}

/// The decision entry files on disk: the markdown directly under
/// `docs/decisions`, minus the index itself. Subdirectories hold generated
/// views and are not entries.
List<String> _entryFiles() {
  final entries = Directory(_decisionsDir)
      .listSync()
      .whereType<File>()
      .map((file) => file.uri.pathSegments.last)
      .where((name) => name.endsWith('.md') && name != 'index.md')
      .toList();
  entries.sort();
  return entries;
}

void _checkIndex() {
  const check = 'the decision index matches the entries on disk';

  final index = File(_decisionsIndex);
  if (!index.existsSync()) {
    throw CheckFailure(check, [
      'no such file: $_decisionsIndex; the index is the tree\'s destination '
          'for the register and both READMEs link to it',
    ]);
  }

  final listed = <String>{};
  for (final link in _linksIn(index)) {
    if (_isExternal(link.target)) continue;

    // The index is a view one directory below the entries, so every entry
    // link climbs out of `views/` first.
    final target = link.target.split('#').first;
    if (!target.startsWith('../') || !target.endsWith('.md')) continue;

    final name = target.substring('../'.length);
    if (name.contains('/')) continue;

    listed.add(name);
  }

  final onDisk = _entryFiles().toSet();

  final reasons = <String>[];
  for (final missing in (onDisk.difference(listed).toList()..sort())) {
    reasons.add(
      '$missing sits in $_decisionsDir but $_decisionsIndex does not list it',
    );
  }
  for (final dangling in (listed.difference(onDisk).toList()..sort())) {
    reasons.add(
      '$_decisionsIndex lists $dangling, which is not an entry file in '
      '$_decisionsDir',
    );
  }

  if (reasons.isNotEmpty) throw CheckFailure(check, reasons);
}

void _checkRetiredEntry() {
  const check = 'the naming entry is retired';

  final names = _entryFiles().where(
    (name) => name.endsWith(_retiredEntrySuffix),
  );
  if (names.isEmpty) {
    throw CheckFailure(check, [
      'no entry file ending in $_retiredEntrySuffix under $_decisionsDir; the '
          'register keeps retired entries so inbound links keep resolving',
    ]);
  }

  final reasons = <String>[];
  for (final name in names) {
    final path = '$_decisionsDir/$name';
    final lines = File(path).readAsLinesSync();

    final front = lines.any((line) => line.trim() == 'status: retired');
    if (!front) {
      reasons.add('$path: the front matter status does not read retired');
    }

    final body = lines.any(
      (line) => line.trim().toLowerCase() == '- status: retired',
    );
    if (!body) {
      reasons.add('$path: the body status line does not read retired');
    }
  }

  if (reasons.isNotEmpty) throw CheckFailure(check, reasons);
}
