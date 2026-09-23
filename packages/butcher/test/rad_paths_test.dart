import 'package:path/path.dart' as p;
import 'package:butcher/butcher.dart';
import 'package:test/test.dart';

void main() {
  test('RAD_TEMP redirects the exact production root', () {
    final root = p.join('somewhere', 'rad');

    final paths = RadPaths.production(environment: {'RAD_TEMP': root});

    expect(paths.root, p.normalize(p.absolute(root)));
  });

  test('an empty RAD_TEMP keeps the system temp root', () {
    expect(
      RadPaths.production(environment: const {'RAD_TEMP': ''}).root,
      RadPaths.systemTemp().root,
    );
  });
}
