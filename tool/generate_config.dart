import 'dart:io';

import 'config_model.dart';

void main(List<String> args) {
  final release = args.contains('--release');
  final help = args.contains('-h') || args.contains('--help');
  if (help) {
    stdout.writeln(
      'Usage: dart run tool/generate_config.dart [--release]\n'
      '\n'
      'Reads config/agentforge.config.json (or AGENTFORGE_CONFIG, or the\n'
      'checked-in example), validates, and writes selected outputs.\n'
      '\n'
      '  (default)   build-safe validation; rewrite selected Dart;\n'
      '              with real config write only gitignored *.local natives\n'
      '  --release   also fail closed on empty/malformed signing fields\n',
    );
    return;
  }

  try {
    final repoRoot = findRepoRoot();
    final configFile = resolveConfigFile(repoRoot);
    generateConfigOutputs(
      repoRoot: repoRoot,
      configFile: configFile,
      release: release,
      log: stdout.writeln,
    );
  } on ConfigValidationException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } catch (_) {
    // Never dump absolute paths or stacks in normal mode.
    stderr.writeln('generate_config failed');
    exitCode = 1;
  }
}

/// Library entry point for tests — pass an isolated [repoRoot], never an env root.
void generateConfigOutputs({
  required Directory repoRoot,
  required File configFile,
  required bool release,
  void Function(String message)? log,
}) {
  final say = log ?? (_) {};
  final json = loadConfigJson(configFile);
  final config = parseAndValidateBuildSafe(json);
  if (release) {
    validateRelease(config);
  }

  const selectedRel = 'lib/core/config/generated/app_config.selected.dart';
  File(
    '${repoRoot.path}/$selectedRel',
  ).writeAsStringSync(renderSelectedDart(config));
  say('Wrote $selectedRel');

  // Source selection decides native write policy — not origin equality.
  if (isRealConfigSource(configFile, repoRoot)) {
    // Never overwrite tracked synthetic natives — only gitignored locals.
    // Entitlement file selection deferred to AF-014.
    const localPropsRel = 'agentforge-config.local.properties';
    File(
      '${repoRoot.path}/$localPropsRel',
    ).writeAsStringSync(renderProperties(config));
    say('Wrote $localPropsRel');

    const localXcRel = 'ios/Flutter/AgentForge.local.xcconfig';
    File(
      '${repoRoot.path}/$localXcRel',
    ).writeAsStringSync(renderXcconfig(config));
    say('Wrote $localXcRel');
  } else {
    // Idempotent refresh of tracked synthetic natives from example only.
    const propsRel = 'agentforge-config.properties';
    File(
      '${repoRoot.path}/$propsRel',
    ).writeAsStringSync(renderProperties(config));
    say('Refreshed $propsRel (synthetic)');

    const xcRel = 'ios/Flutter/AgentForge.xcconfig';
    File('${repoRoot.path}/$xcRel').writeAsStringSync(renderXcconfig(config));
    say('Refreshed $xcRel (synthetic)');
  }

  if (release) {
    say('Release validation OK (signing present).');
  }
}
