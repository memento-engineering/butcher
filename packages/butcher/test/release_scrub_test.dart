import 'dart:io';

import 'package:test/test.dart';

/// Tokens the org's release scrub refuses to see in a published README or
/// CHANGELOG. All four were common in the prose this package inherited, so
/// their absence is pinned here rather than discovered at tag time.
const _scrubTokens = ['decision register', 'the register', 'ADR', 'spike'];

/// The upstream author's MIT copyright line. The grant redistributes only
/// while this notice travels with the derivative work, so it is matched
/// verbatim.
const _upstreamCopyright = 'Copyright (c) 2026 Ricardo Boss';

/// The org's own copyright line for the derivative work, added beside the
/// upstream one and never in its place.
const _orgCopyright = 'Copyright (c) 2026 memento-engineering';

/// The MIT permission notice, which must survive byte-identical in every
/// member's LICENSE.
const _permissionNotice =
    'Permission is hereby granted, free of charge, to any person obtaining a '
    'copy\n'
    'of this software and associated documentation files (the "Software"), to '
    'deal\n'
    'in the Software without restriction, including without limitation the '
    'rights\n'
    'to use, copy, modify, merge, publish, distribute, sublicense, and/or '
    'sell\n'
    'copies of the Software, and to permit persons to whom the Software is\n'
    'furnished to do so, subject to the following conditions:\n'
    '\n'
    'The above copyright notice and this permission notice shall be included '
    'in all\n'
    'copies or substantial portions of the Software.';

/// Every LICENSE this bead owns, by path relative to this package's root.
const _licenses = [
  'LICENSE',
  '../butcher_process/LICENSE',
  '../butcher_report/LICENSE',
];

String _read(String relativePath) {
  final file = File(relativePath);
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'run this suite from the package root, where $relativePath resolves',
  );
  return file.readAsStringSync();
}

void main() {
  group('the release scrub', () {
    for (final published in ['README.md', 'CHANGELOG.md']) {
      for (final token in _scrubTokens) {
        test('$published carries no "$token"', () {
          expect(_read(published), isNot(contains(token)));
        });
      }
    }
  });

  group('the changelog', () {
    late String changelog;

    setUp(() => changelog = _read('CHANGELOG.md'));

    test('has exactly one version heading', () {
      final headings = RegExp(
        r'^##\s+(\S+)\s*$',
        multiLine: true,
      ).allMatches(changelog).map((m) => m.group(1)).toList();

      expect(headings, ['0.1.0']);
    });

    test('states the fork in its first entry', () {
      expect(changelog, contains('radioactive_dart'));
      expect(changelog, contains('Ricardo Boss'));
    });
  });

  group('every member LICENSE', () {
    for (final license in _licenses) {
      test('$license keeps the upstream notice beside the org line', () {
        final text = _read(license);

        expect(
          text,
          contains(_upstreamCopyright),
          reason: 'the upstream copyright line must travel with the fork',
        );
        expect(text, contains(_orgCopyright));
        expect(
          text.indexOf(_orgCopyright),
          lessThan(text.indexOf(_upstreamCopyright)),
          reason: "the org's line is added above the upstream one",
        );
        expect(
          text,
          contains(_permissionNotice),
          reason: 'the MIT permission notice must survive unchanged',
        );
      });
    }
  });

  test('the published README states the derivation above its usage', () {
    final readme = _read('README.md');
    final derivation = readme.indexOf('Ricardo Boss');
    final usage = readme.indexOf('\n## Usage');

    expect(readme, contains('radioactive_dart'));
    expect(derivation, isNonNegative);
    expect(usage, isNonNegative);
    expect(derivation, lessThan(usage));
  });
}
