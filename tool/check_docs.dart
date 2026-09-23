/// Asserts that the documentation tree hangs together.
///
/// A shell grep can prove a word is gone; it cannot resolve a markdown link or
/// reconcile an index against the files on disk. These checks walk `docs/`,
/// resolve every relative link target, reconcile the decision index against the
/// entry files it views in both directions, assert that the superseded entry
/// names its successor, and assert that each amended or new decision entry
/// still states the subject it was written to state.
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
const _supersededEntry = '$_decisionsDir/2026-08-14-naming-and-vocabulary.md';
const _successorSlug = 'standard-mutation-vocabulary';

/// What one entry file must and must not say.
///
/// Every subject here is one this repository decided and then changed its mind
/// about, or one it decided and never wrote down; a grep for the subject is
/// what stops the entry drifting back to the argument it replaced.
typedef Subject = ({String file, List<String> says, List<String> neverSays});

const _subjects = <Subject>[
  (
    file: '$_decisionsDir/2026-08-14-shadow-copy-isolation.md',
    says: [
      'git ls-files --cached --others --exclude-standard --deduplicate -z',
      'always-include',
      'hierarchical walk',
      // Both enumerations, re-run on this repository.
      '218',
      '663,910',
      '219',
      '675,097',
    ],
    neverSays: ['.butcherignore', 'ignore file', 'gitignore-style'],
  ),
  (
    file: '$_decisionsDir/2026-08-21-process-interlock.md',
    says: [
      // The group spawn Dart was said to be incapable of.
      'execs the rest of its argument vector in place',
      // Membership inheritance, scoped to the platform that has it.
      'Membership is inherited there',
      // The session escape, pinned by a test and carrying no rate.
      'posix_interlock_test.dart',
      'No escape rate is recorded',
      // Why that escape is not a new hole.
      'reparented to pid 1',
      // Why the interlock owns the spawn.
      'setpgid',
      // What the adoption deleted.
      'descendant walker are deleted',
    ],
    neverSays: [
      'Dart cannot spawn a process group',
      'Membership is inherited, so everything the suite spawns joins it',
      'POSIX keeps the sweep',
    ],
  ),
  (
    file: '$_decisionsDir/2026-08-14-outcome-taxonomy.md',
    says: ['75 of 709 healthy', '2026-08-21'],
    neverSays: [],
  ),
  (
    file: '$_decisionsDir/2026-08-14-stryker-json-primary-report.md',
    says: ['butcher_report', 'unthemed'],
    neverSays: [],
  ),
  (
    file: '$_decisionsDir/2026-09-22-value-equality-boundary.md',
    says: [
      // The five that gained equality.
      '`Mutation`',
      '`Mutant`',
      '`MutantResult`',
      '`TestRun`',
      '`TestSuite`',
      // The three that deliberately did not.
      '`TestEvents`',
      '`CappedOutput`',
      '`ViabilityChecker`',
    ],
    neverSays: [],
  ),
  (
    file: '$_decisionsDir/2026-09-22-two-mechanism-configuration.md',
    says: [
      'butcher.yaml',
      '`exclude`',
      'never reads the analyzer',
      'no configuration block in any package manifest',
      'no include list, no negation and no re-include',
      'git listing',
    ],
    neverSays: [],
  ),
  (
    file: '$_decisionsDir/2026-09-22-live-event-surface.md',
    says: ['additive', 'NON-DETERMINISTIC', 'in parallel'],
    neverSays: [],
  ),
  (
    file: '$_decisionsDir/2026-09-22-workspace-shape.md',
    says: [
      'packages/butcher`',
      'packages/butcher_process`',
      'packages/butcher_report`',
      'butcher-v0.1.0',
      'prerelease tag push is a routine release',
    ],
    neverSays: [],
  ),
];

/// Phrases that would mean an entry here states where the tool sits in the
/// organisation; that ruling belongs to the organisation's own register.
const _orgPlacementPhrases = [
  'org placement',
  'org-placement',
  'organisation placement',
  'organization placement',
];

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
    (name: 'the naming entry names its successor', run: _checkSupersededEntry),
    (
      name: 'every amended or new entry states its subject',
      run: _checkSubjects,
    ),
    (name: 'no entry states an org-placement ruling', run: _checkOrgPlacement),
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

void _checkSupersededEntry() {
  const check = 'the naming entry names its successor';

  final file = File(_supersededEntry);
  if (!file.existsSync()) {
    throw CheckFailure(check, [
      'no such file: $_supersededEntry; the register keeps superseded entries '
          'so inbound links keep resolving',
    ]);
  }

  final reasons = <String>[];
  final lines = file.readAsLinesSync();

  // The register's own force operation writes this line; a hand-written
  // status value would not be one the register spec supports.
  final front = lines.any(
    (line) => line.trim() == 'status: superseded by $_successorSlug',
  );
  if (!front) {
    reasons.add(
      '$_supersededEntry: the front matter status is not the one the '
      "register's obsolete operation writes",
    );
  }

  if (!lines.any((line) => line.trim() == 'obsoleted-by: $_successorSlug')) {
    reasons.add('$_supersededEntry: no obsoleted-by edge to $_successorSlug');
  }

  if (!file.readAsStringSync().contains(_successorSlug)) {
    reasons.add('$_supersededEntry: the body never names $_successorSlug');
  }

  if (reasons.isNotEmpty) throw CheckFailure(check, reasons);
}

/// [text] with every run of whitespace collapsed to one space, so a phrase
/// matches however the markdown happens to be wrapped.
String _flattened(String text) => text.replaceAll(RegExp(r'\s+'), ' ');

void _checkSubjects() {
  const check = 'every amended or new entry states its subject';

  final reasons = <String>[];
  for (final subject in _subjects) {
    final file = File(subject.file);
    if (!file.existsSync()) {
      reasons.add('no such entry: ${subject.file}');
      continue;
    }

    final text = _flattened(file.readAsStringSync());
    for (final phrase in subject.says) {
      if (!text.contains(phrase)) {
        reasons.add('${subject.file} no longer states "$phrase"');
      }
    }
    for (final phrase in subject.neverSays) {
      if (text.contains(phrase)) {
        reasons.add('${subject.file} states "$phrase" again');
      }
    }
  }

  if (reasons.isNotEmpty) throw CheckFailure(check, reasons);
}

void _checkOrgPlacement() {
  const check = 'no entry states an org-placement ruling';

  final reasons = <String>[];
  for (final name in _entryFiles()) {
    final path = '$_decisionsDir/$name';
    final text = _flattened(File(path).readAsStringSync()).toLowerCase();
    for (final phrase in _orgPlacementPhrases) {
      if (text.contains(phrase)) {
        reasons.add(
          '$path states "$phrase"; where this tool sits in the organisation '
          "is the organisation's own register to record",
        );
      }
    }
  }

  if (reasons.isNotEmpty) throw CheckFailure(check, reasons);
}
