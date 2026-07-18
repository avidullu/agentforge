import 'dart:convert';
import 'dart:io';

class ChangedLine {
  const ChangedLine({
    required this.path,
    required this.line,
    required this.text,
  });

  final String path;
  final int line;
  final String text;
}

class DiffCoverageResult {
  const DiffCoverageResult({
    required this.found,
    required this.hit,
    required this.uncovered,
  });

  final int found;
  final int hit;
  final Map<String, List<int>> uncovered;

  double get percent => found == 0 ? 100 : hit * 100 / found;
}

String normalizeCoveragePath(String raw, {String? repoRoot}) {
  var path = raw.trim();
  if (path.startsWith('file:')) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.scheme == 'file') {
      path = uri.toFilePath(windows: Platform.isWindows);
    }
  }
  path = path.replaceAll('\\', '/');

  String clean(String value) {
    var result = value.replaceAll('\\', '/');
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  if (repoRoot != null && repoRoot.trim().isNotEmpty) {
    final root = clean(repoRoot);
    final comparePath = Platform.isWindows ? path.toLowerCase() : path;
    final compareRoot = Platform.isWindows ? root.toLowerCase() : root;
    if (comparePath == compareRoot) return '';
    if (comparePath.startsWith('$compareRoot/')) {
      path = path.substring(root.length + 1);
    } else if (_isAbsolutePath(path)) {
      // Production passes repoRoot. Never let an executed dependency with a
      // colliding `/lib/...` suffix contribute hits to repository coverage.
      return '';
    }
  }

  while (path.startsWith('./')) {
    path = path.substring(2);
  }

  if (repoRoot == null && !path.startsWith('lib/')) {
    final marker = path.indexOf('/lib/');
    if (marker >= 0) path = path.substring(marker + 1);
  }
  return path;
}

bool _isAbsolutePath(String path) {
  return path.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(path);
}

Map<String, Map<int, int>> parseLcov(String contents, {String? repoRoot}) {
  final result = <String, Map<int, int>>{};
  String? currentPath;

  for (final line in contents.split(RegExp(r'\r?\n'))) {
    if (line.startsWith('SF:')) {
      final normalized = normalizeCoveragePath(
        line.substring(3),
        repoRoot: repoRoot,
      );
      currentPath = normalized.isEmpty ? null : normalized;
      if (currentPath != null) {
        result.putIfAbsent(currentPath, () => <int, int>{});
      }
    } else if (line.startsWith('DA:') && currentPath != null) {
      final fields = line.substring(3).split(',');
      if (fields.length < 2) continue;
      final lineNumber = int.tryParse(fields[0]);
      final hits = int.tryParse(fields[1]);
      if (lineNumber == null || hits == null) continue;
      final sourceLines = result[currentPath]!;
      final existing = sourceLines[lineNumber];
      if (existing == null || hits > existing) {
        sourceLines[lineNumber] = hits;
      }
    } else if (line == 'end_of_record') {
      currentPath = null;
    }
  }

  return result;
}

List<String> parseNullSeparatedUtf8(Object raw) {
  final bytes = raw is List<int> ? raw : utf8.encode(raw.toString());
  final paths = <String>[];
  var start = 0;
  for (var index = 0; index < bytes.length; index++) {
    if (bytes[index] != 0) continue;
    if (index > start) {
      paths.add(utf8.decode(bytes.sublist(start, index)));
    }
    start = index + 1;
  }
  if (start < bytes.length) {
    paths.add(utf8.decode(bytes.sublist(start)));
  }
  return paths;
}

List<String> parseAddedPathsFromNumstat(Object raw) {
  final records = parseNullSeparatedUtf8(raw);
  final paths = <String>[];

  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    final firstTab = record.indexOf('\t');
    final secondTab = firstTab < 0 ? -1 : record.indexOf('\t', firstTab + 1);
    if (firstTab <= 0 || secondTab < 0) {
      throw const FormatException('Malformed NUL-safe numstat record.');
    }

    final additions = int.tryParse(record.substring(0, firstTab));
    if (additions == null || additions < 0) {
      throw const FormatException('Invalid numstat additions count.');
    }
    var path = record.substring(secondTab + 1);
    if (path.isEmpty) {
      // With `--numstat -z`, a rename/copy record ends its numeric prefix
      // with NUL, followed by separate old-path and new-path NUL fields.
      if (index + 2 >= records.length) {
        throw const FormatException('Incomplete numstat rename record.');
      }
      index++; // The old path is intentionally ignored.
      path = records[++index];
      if (path.isEmpty) {
        throw const FormatException('Empty numstat destination path.');
      }
    }
    if (additions > 0) {
      paths.add(path);
    }
  }

  return paths;
}

Set<String> eligibleDartPaths(Iterable<String> paths) {
  return paths
      .map(normalizeCoveragePath)
      .where((path) => path.startsWith('lib/') && path.endsWith('.dart'))
      .toSet();
}

Set<String> unparsedEligibleDartPaths({
  required Iterable<String> expectedPaths,
  required Iterable<String> parsedPaths,
}) {
  final expected = eligibleDartPaths(expectedPaths);
  final parsed = eligibleDartPaths(parsedPaths);
  return expected.difference(parsed);
}

double? parseCoverageFloor(String raw) {
  final value = double.tryParse(raw);
  if (value == null || !value.isFinite || value < 0 || value > 100) {
    return null;
  }
  return value;
}

Map<String, List<ChangedLine>> parseUnifiedDiff(String contents) {
  final result = <String, List<ChangedLine>>{};
  final hunk = RegExp(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@');
  String? currentPath;
  int? currentNewLine;

  for (final rawLine in contents.split(RegExp(r'\r?\n'))) {
    if (rawLine.startsWith('diff --git ')) {
      currentPath = null;
      currentNewLine = null;
      continue;
    }
    // A legal added Dart line such as `++ value;` is encoded as
    // `+++ value;`. Only recognize the patch header before a hunk begins.
    if (currentNewLine == null && rawLine.startsWith('+++ ')) {
      final value = rawLine.substring(4).trim();
      if (value == '/dev/null') {
        currentPath = null;
      } else {
        currentPath = value.startsWith('b/') ? value.substring(2) : value;
        currentPath = currentPath.replaceAll('\\', '/');
        result.putIfAbsent(currentPath, () => <ChangedLine>[]);
      }
      currentNewLine = null;
      continue;
    }

    final match = hunk.firstMatch(rawLine);
    if (match != null) {
      currentNewLine = int.parse(match.group(1)!);
      continue;
    }
    if (currentPath == null || currentNewLine == null) continue;
    if (rawLine.startsWith('\\ No newline at end of file')) continue;

    if (rawLine.startsWith('+')) {
      result[currentPath]!.add(
        ChangedLine(
          path: currentPath,
          line: currentNewLine,
          text: rawLine.substring(1),
        ),
      );
      currentNewLine++;
    } else if (rawLine.startsWith('-')) {
      // A deleted line does not advance the new-file line counter.
    } else {
      currentNewLine++;
    }
  }

  return result;
}

DiffCoverageResult evaluateDiffCoverage({
  required Map<String, Map<int, int>> lcov,
  required Map<String, List<ChangedLine>> changed,
}) {
  var found = 0;
  var hit = 0;
  final uncovered = <String, List<int>>{};

  for (final entry in changed.entries) {
    final path = normalizeCoveragePath(entry.key);
    if (!path.startsWith('lib/') || !path.endsWith('.dart')) continue;
    final sourceCoverage = lcov[path];

    if (sourceCoverage == null) {
      for (final line in entry.value.where(_looksLikeCode)) {
        found++;
        uncovered.putIfAbsent(path, () => <int>[]).add(line.line);
      }
      continue;
    }

    for (final line in entry.value) {
      final lineHits = sourceCoverage[line.line];
      if (lineHits == null) continue;
      found++;
      if (lineHits > 0) {
        hit++;
      } else {
        uncovered.putIfAbsent(path, () => <int>[]).add(line.line);
      }
    }
  }

  return DiffCoverageResult(found: found, hit: hit, uncovered: uncovered);
}

bool _looksLikeCode(ChangedLine line) {
  final value = line.text.trim();
  if (value.isEmpty) return false;
  if (value.startsWith('//') ||
      value.startsWith('/*') ||
      value.startsWith('*') ||
      value == '*/') {
    return false;
  }
  return true;
}
