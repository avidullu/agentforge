import 'dart:io';

import 'config_model.dart';
import 'pii_guard.dart';

void main(List<String> args) {
  final help = args.contains('-h') || args.contains('--help');
  if (help) {
    stdout.writeln(
      'Usage: dart run tool/check_no_pii.dart --mode=report|blocklist|structural\n'
      '       [--scope=tracked|fixture] [--root=<dir>] [--blocklist=<file>]\n'
      '\n'
      'Modes:\n'
      '  report       Print hits; always exit 0 (S1 CI on real tree)\n'
      '  blocklist    Fail closed on blocklist hits (S7 / fixture tests)\n'
      '  structural   Fail closed on non-synthetic HTTPS origins in scope\n'
      '\n'
      'Scopes:\n'
      '  tracked      git ls-files -z (NUL-safe)\n'
      '  fixture      recurse --root (default: test/config/fixtures)\n'
      '\n'
      'Blocklist file: --blocklist or \$AGENTFORGE_PII_BLOCKLIST\n',
    );
    return;
  }

  try {
    final mode = _parseMode(_flag(args, 'mode') ?? 'report');
    final scope = _flag(args, 'scope') ?? 'tracked';
    final repoRoot = findRepoRoot();
    final rootFlag = _flag(args, 'root');

    final List<File> files;
    if (scope == 'tracked') {
      files = listTrackedFiles(repoRoot);
    } else if (scope == 'fixture') {
      final root = Directory(
        rootFlag ?? '${repoRoot.path}/test/config/fixtures',
      );
      files = listFilesRecursive(root);
    } else {
      stderr.writeln('Unknown --scope=$scope (use tracked|fixture)');
      exitCode = 64;
      return;
    }

    List<PiiHit> hits;
    if (mode == PiiMode.structural) {
      hits = scanStructuralHttps(files: files, repoRoot: repoRoot.path);
    } else {
      final blocklistPath =
          _flag(args, 'blocklist') ??
          Platform.environment['AGENTFORGE_PII_BLOCKLIST'];
      if (blocklistPath == null || blocklistPath.isEmpty) {
        if (mode == PiiMode.report && scope == 'tracked') {
          stdout.writeln(
            'PII report: no blocklist configured '
            '(\$AGENTFORGE_PII_BLOCKLIST / --blocklist); '
            'skipping content scan (report-only no-op).',
          );
          exitCode = 0;
          return;
        }
        stderr.writeln(
          'Blocklist required for mode=${mode.name} '
          '(set AGENTFORGE_PII_BLOCKLIST or --blocklist)',
        );
        exitCode = 64;
        return;
      }
      final patterns = loadBlocklistPatterns(File(blocklistPath));
      hits = scanWithBlocklist(
        files: files,
        patterns: patterns,
        repoRoot: repoRoot.path,
      );
    }

    if (hits.isEmpty) {
      stdout.writeln(
        'PII ${mode.name}: clean (${files.length} files, scope=$scope)',
      );
      exitCode = 0;
      return;
    }

    stdout.writeln('PII ${mode.name}: ${hits.length} hit(s) in scope=$scope');
    for (final h in hits) {
      stdout.writeln('  $h');
    }

    if (mode == PiiMode.report) {
      exitCode = 0;
    } else {
      exitCode = 1;
    }
  } catch (e, st) {
    stderr.writeln(e);
    stderr.writeln(st);
    exitCode = 1;
  }
}

PiiMode _parseMode(String raw) {
  switch (raw) {
    case 'report':
      return PiiMode.report;
    case 'blocklist':
      return PiiMode.blocklist;
    case 'structural':
      return PiiMode.structural;
    default:
      throw FormatException('Unknown --mode=$raw');
  }
}

String? _flag(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}
