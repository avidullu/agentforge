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
      '  --release   also fail closed on empty signing fields\n',
    );
    return;
  }

  try {
    final repoRoot = findRepoRoot();
    final configFile = resolveConfigFile(repoRoot);
    final json = loadConfigJson(configFile);
    final config = parseAndValidateBuildSafe(json);
    if (release) {
      validateRelease(config);
    }

    final selectedPath =
        '${repoRoot.path}/lib/core/config/generated/app_config.selected.dart';
    File(selectedPath).writeAsStringSync(renderSelectedDart(config));
    stdout.writeln('Wrote $selectedPath (origin=${config.origin})');

    final usingReal =
        !config.isSyntheticOrigin ||
        configFile.path.endsWith('agentforge.config.json') ||
        Platform.environment.containsKey('AGENTFORGE_CONFIG');

    if (usingReal && !config.isSyntheticOrigin) {
      // Never overwrite tracked synthetic natives — only gitignored locals.
      final localProps = File(
        '${repoRoot.path}/agentforge-config.local.properties',
      );
      localProps.writeAsStringSync(renderProperties(config));
      stdout.writeln('Wrote ${localProps.path}');

      final localXc = File(
        '${repoRoot.path}/ios/Flutter/AgentForge.local.xcconfig',
      );
      localXc.writeAsStringSync(
        '${renderXcconfig(config)}\n${renderLocalXcconfigWithEntitlements()}',
      );
      stdout.writeln('Wrote ${localXc.path}');

      final entitlementsLocal = File(
        '${repoRoot.path}/ios/Runner/Runner.entitlements.local',
      );
      entitlementsLocal.writeAsStringSync(renderEntitlementsLocal(config));
      stdout.writeln('Wrote ${entitlementsLocal.path}');
    } else if (config.isSyntheticOrigin) {
      // Idempotent refresh of tracked synthetic natives from example.
      final props = File('${repoRoot.path}/agentforge-config.properties');
      props.writeAsStringSync(renderProperties(config));
      stdout.writeln('Refreshed ${props.path} (synthetic)');

      final xc = File('${repoRoot.path}/ios/Flutter/AgentForge.xcconfig');
      xc.writeAsStringSync(renderXcconfig(config));
      stdout.writeln('Refreshed ${xc.path} (synthetic)');
    }

    if (release) {
      stdout.writeln('Release validation OK (signing present).');
    }
  } on ConfigValidationException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  } catch (e, st) {
    stderr.writeln(e);
    stderr.writeln(st);
    exitCode = 1;
  }
}
