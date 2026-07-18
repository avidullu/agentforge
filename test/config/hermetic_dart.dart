import 'dart:io';

/// Dart executable for the same SDK running this test process.
///
/// Avoids PATH lookup of a separate system Dart that fails with
/// "Invalid SDK hash" under `flutter test` (review finding).
String hermeticDartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    final suffix = Platform.isWindows ? '.exe' : '';
    final candidate = File('$flutterRoot/bin/cache/dart-sdk/bin/dart$suffix');
    if (candidate.existsSync()) return candidate.path;
  }

  final resolved = Platform.resolvedExecutable;
  final base = resolved.split(Platform.pathSeparator).last.toLowerCase();
  if (base == 'dart' || base == 'dart.exe') {
    return resolved;
  }

  // flutter_tester / other host: look beside resolved binary.
  final dir = File(resolved).parent.path;
  final suffix = Platform.isWindows ? '.exe' : '';
  final sibling = File('$dir/dart$suffix');
  if (sibling.existsSync()) return sibling.path;

  // Last resort: still prefer resolved over bare PATH `dart`.
  return resolved;
}
