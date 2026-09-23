import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

void main() {
  test('BUTCHER_TEMP redirects the exact production root', () {
    final root = p.join('somewhere', 'butcher');

    final paths = ButcherPaths.production(environment: {'BUTCHER_TEMP': root});

    expect(paths.root, p.normalize(p.absolute(root)));
  });

  test('an empty BUTCHER_TEMP keeps the system temp root', () {
    expect(
      ButcherPaths.production(environment: const {'BUTCHER_TEMP': ''}).root,
      ButcherPaths.systemTemp().root,
    );
  });
}
