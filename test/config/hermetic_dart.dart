import 'dart:io';

/// Dart CLI executable for the same SDK running this test process.
///
/// Never falls back to a bare PATH `dart` or a non-Dart host such as
/// `flutter_tester` without a proven sibling CLI (review 264).
String hermeticDartExecutable() {
  final suffix = Platform.isWindows ? '.exe' : '';
  final candidates = <File>[];

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.trim().isNotEmpty) {
    candidates.add(File('$flutterRoot/bin/cache/dart-sdk/bin/dart$suffix'));
  }

  final resolved = File(Platform.resolvedExecutable);
  final base = resolved.uri.pathSegments.isNotEmpty
      ? resolved.uri.pathSegments.last.toLowerCase()
      : '';
  if (base == 'dart' || base == 'dart.exe') {
    candidates.add(resolved);
  } else {
    // flutter_tester / other host binary — only accept a real dart sibling.
    candidates.add(File('${resolved.parent.path}/dart$suffix'));
  }

  for (final c in candidates) {
    if (c.existsSync()) return c.absolute.path;
  }

  throw StateError(
    'hermetic Dart CLI not found (set FLUTTER_ROOT or run under Flutter SDK)',
  );
}
