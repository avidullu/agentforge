import 'dart:convert';
import 'dart:io';

/// One PII / structural hit in a scanned path.
///
/// [patternLabel] is a redacted category only — never store the matched value
/// (blocklist mode would otherwise leak private patterns into CI logs).
class PiiHit {
  PiiHit({required this.path, required this.line, required this.patternLabel});

  final String path;
  final int line;
  final String patternLabel;

  @override
  String toString() => '$path:$line [$patternLabel]';
}

/// Modes for [scanPaths].
enum PiiMode {
  /// Always exit 0 from the CLI; print hits.
  report,

  /// Fail closed when any hit is found.
  blocklist,

  /// Structural public gate: only synthetic origin + loopback https hosts.
  structural,
}

const String kSyntheticHttpsOrigin = 'https://forge.example.test';

/// Load blocklist patterns from a private file (one pattern per line).
///
/// Lines starting with `#` and blank lines are ignored. An optional
/// `allow:` section is accepted but not required for S1 fixture tests.
List<String> loadBlocklistPatterns(File file) {
  if (!file.existsSync()) {
    throw StateError('blocklist file missing');
  }
  final patterns = <String>[];
  var inAllow = false;
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.toLowerCase() == 'allow:') {
      inAllow = true;
      continue;
    }
    if (inAllow) continue; // S1: allow section reserved; enforced at S7.
    patterns.add(line);
  }
  return patterns;
}

/// Scan files for blocklist literal substrings (case-insensitive).
List<PiiHit> scanWithBlocklist({
  required Iterable<File> files,
  required List<String> patterns,
  String repoRoot = '',
}) {
  final hits = <PiiHit>[];
  final lowerPatterns = patterns
      .map((p) => MapEntry(p, p.toLowerCase()))
      .where((e) => e.value.isNotEmpty)
      .toList();

  for (final file in files) {
    if (!file.existsSync()) continue;
    final rel = repoRoot.isEmpty ? file.path : _relPath(file.path, repoRoot);
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      // Binary / unreadable — skip for content scan.
      continue;
    }
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      for (final entry in lowerPatterns) {
        if (lower.contains(entry.value)) {
          hits.add(
            PiiHit(
              path: rel,
              line: i + 1,
              // Redacted category only — never echo the matched value.
              patternLabel: 'blocklist',
            ),
          );
          break;
        }
      }
    }
  }
  return hits;
}

/// Structural rule for public CI (after S7 will be fail-closed):
/// In scoped sources, the only allowed non-loopback `https://` origin
/// literal is [kSyntheticHttpsOrigin] exactly. Loopback fixtures remain allowed.
List<PiiHit> scanStructuralHttps({
  required Iterable<File> files,
  String repoRoot = '',
}) {
  final hits = <PiiHit>[];
  for (final file in files) {
    if (!file.existsSync()) continue;
    final rel = repoRoot.isEmpty ? file.path : _relPath(file.path, repoRoot);
    List<String> lines;
    try {
      lines = file.readAsLinesSync();
    } catch (_) {
      continue;
    }
    hits.addAll(scanStructuralHttpsLines(path: rel, lines: lines));
  }
  return hits;
}

/// Structural scan over already-loaded [lines].
///
/// Shared by the worktree scan and the staged-blob scan so a pre-commit guard
/// and CI can never diverge on what counts as an allowed literal.
List<PiiHit> scanStructuralHttpsLines({
  required String path,
  required List<String> lines,
}) {
  // Capture whole literal; do not truncate at `@` / `?` / `#` (review 264).
  final httpsRe = RegExp(
    r'''https://[^\s"'<>\)\]\},]+''',
    caseSensitive: false,
  );
  final hits = <PiiHit>[];
  for (var i = 0; i < lines.length; i++) {
    for (final match in httpsRe.allMatches(lines[i])) {
      if (_isAllowedHttpsLiteral(match.group(0)!)) continue;
      hits.add(
        PiiHit(path: path, line: i + 1, patternLabel: 'structural-https'),
      );
    }
  }
  return hits;
}

bool _isAllowedHttpsLiteral(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return false;
  if (uri.userInfo.isNotEmpty) return false;

  final host = uri.host.toLowerCase();
  // Loopback fixtures for mock-agent tests (any path/port).
  if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
    return scheme == 'http' || scheme == 'https';
  }
  // Only the approved JSON Schema meta $schema literal (draft 2020-12).
  if (scheme == 'https' &&
      host == 'json-schema.org' &&
      !uri.hasPort &&
      uri.userInfo.isEmpty &&
      uri.query.isEmpty &&
      uri.fragment.isEmpty &&
      uri.path == '/draft/2020-12/schema') {
    return true;
  }

  // Exact synthetic origin only (docs/11 §8.1) — no path/query/fragment/port/userinfo.
  if (scheme != 'https') return false;
  if (host != 'forge.example.test') return false;
  if (uri.hasPort && uri.port != 443) return false;
  if (uri.path.isNotEmpty && uri.path != '/') return false;
  if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) return false;
  return true;
}

/// List tracked files via `git ls-files -z` (NUL-safe).
List<File> listTrackedFiles(Directory repoRoot) {
  return _gitNulPaths(repoRoot, const ['ls-files', '-z'], 'git ls-files')
      .map((p) => File('${repoRoot.path}${Platform.pathSeparator}$p'))
      .where((f) => f.existsSync())
      .toList();
}

/// Repo-relative paths staged for commit (added/copied/modified/renamed).
///
/// Deletions are excluded: a removed blob cannot leak anything.
List<String> listStagedPaths(Directory repoRoot) {
  return _gitNulPaths(repoRoot, const [
    'diff',
    '--cached',
    '--name-only',
    '-z',
    '--diff-filter=ACMR',
  ], 'git diff --cached');
}

/// Read the *staged* (index) content of [path], not the worktree copy.
///
/// The distinction is the whole point of the pre-commit guard: `git add` snapshots
/// content into the index, so a later worktree edit must not hide what is about
/// to be committed. Returns null for binary/unreadable blobs.
String? readStagedBlob(Directory repoRoot, String path) {
  final result = Process.runSync(
    'git',
    ['show', ':$path'],
    workingDirectory: repoRoot.path,
    stdoutEncoding: null,
  );
  if (result.exitCode != 0) return null;
  final raw = result.stdout;
  final bytes = raw is List<int> ? raw : utf8.encode(raw as String);
  if (bytes.contains(0)) return null; // binary
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return null;
  }
}

/// Tracked files that `tool/generate_config.dart` rewrites.
///
/// These are the only tracked paths whose HTTPS literals come from build config
/// rather than from prose, so they are the only place the structural rule can be
/// enforced without drowning in false positives (doc links, pubspec.lock URLs,
/// and the scanner's own regex all contain non-synthetic `https://` literals).
const List<String> kGeneratedTrackedConfigPaths = [
  'lib/core/config/generated/app_config.selected.dart',
  'agentforge-config.properties',
  'ios/Flutter/AgentForge.xcconfig',
];

/// Gitignored files holding real config. Staging one (`git add -f`) is always
/// a mistake — they must never enter history.
const List<String> kNeverCommitConfigPaths = [
  'config/agentforge.config.json',
  'agentforge-config.local.properties',
  'ios/Flutter/AgentForge.local.xcconfig',
  'ios/Runner/Runner.entitlements.local',
];

/// Staged paths that must never be committed at all.
List<String> stagedNeverCommitPaths(Directory repoRoot) {
  final staged = listStagedPaths(repoRoot).toSet();
  return kNeverCommitConfigPaths.where(staged.contains).toList();
}

/// Structural scan of staged content, optionally limited to [limitTo].
List<PiiHit> scanStagedStructuralHttps(
  Directory repoRoot, {
  Iterable<String>? limitTo,
}) {
  final allowed = limitTo?.toSet();
  final hits = <PiiHit>[];
  for (final path in listStagedPaths(repoRoot)) {
    if (allowed != null && !allowed.contains(path)) continue;
    final content = readStagedBlob(repoRoot, path);
    if (content == null) continue;
    hits.addAll(
      scanStructuralHttpsLines(
        path: path,
        lines: const LineSplitter().convert(content),
      ),
    );
  }
  return hits;
}

List<String> _gitNulPaths(Directory repoRoot, List<String> args, String label) {
  final result = Process.runSync(
    'git',
    args,
    workingDirectory: repoRoot.path,
    stdoutEncoding: null,
  );
  if (result.exitCode != 0) {
    throw StateError('$label failed');
  }
  final raw = result.stdout;
  final bytes = raw is List<int> ? raw : utf8.encode(raw as String);
  final parts = <String>[];
  final chunk = <int>[];
  for (final b in bytes) {
    if (b == 0) {
      if (chunk.isNotEmpty) {
        parts.add(utf8.decode(chunk));
        chunk.clear();
      }
    } else {
      chunk.add(b);
    }
  }
  if (chunk.isNotEmpty) parts.add(utf8.decode(chunk));
  return parts;
}

/// List files under a directory (fixture roots).
List<File> listFilesRecursive(Directory root) {
  if (!root.existsSync()) return const [];
  return root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .toList();
}

String _relPath(String absolute, String root) {
  final normRoot = root.endsWith(Platform.pathSeparator)
      ? root
      : '$root${Platform.pathSeparator}';
  if (absolute.startsWith(normRoot)) {
    return absolute.substring(normRoot.length).replaceAll('\\', '/');
  }
  return absolute.replaceAll('\\', '/');
}
