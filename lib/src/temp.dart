import 'dart:io';

import 'package:path/path.dart' as p;

/// Path of the single folder holding all rad temp data: `<system temp>/rad`.
String radTempPath() => p.join(Directory.systemTemp.path, 'rad');

/// Creates the rad temp root if needed and returns it.
///
/// Everything rad writes to the temp dir (containment copies, the log
/// file) lives below this folder, keeping the temp dir uncluttered.
Directory radTempRoot() =>
    Directory(radTempPath())..createSync(recursive: true);
