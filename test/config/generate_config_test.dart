import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/config_model.dart';
import 'hermetic_dart.dart';

/// Valid Android assetlinks SHA-256 fingerprint (32 colon-separated hex pairs).
const kValidFingerprint =
    'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:'
    'AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99';

const kValidTeamId = 'ABCD123456';

void main() {
  final repoRoot = findRepoRoot();
  final dartBin = hermeticDartExecutable();

  group('parseAndValidateBuildSafe', () {
    test('accepts the checked-in example config', () {
      final file = File(
        '${repoRoot.path}/config/agentforge.config.example.json',
      );
      final config = parseAndValidateBuildSafe(loadConfigJson(file));
      expect(config.origin, kSyntheticOrigin);
      expect(config.trustedHost, 'forge.example.test');
      expect(config.applicationId, 'com.example.agentforge');
      expect(config.gradleNamespace, 'dev.agentforge.app');
      expect(config.urlScheme, 'agentforge');
      expect(config.isSyntheticOrigin, isTrue);
    });

    test('rejects non-443 port', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': 'https://forge.example.test:8443'},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
        }),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('rejects path on origin', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': 'https://forge.example.test/forgejo'},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
        }),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('rejects forbidden secret property names', () {
      expect(
        () => loadConfigJson(
          _tempJson({
            'schemaVersion': 1,
            'forgejo': {'origin': kSyntheticOrigin},
            'app': {
              'applicationId': 'com.example.agentforge',
              'gradleNamespace': 'dev.agentforge.app',
              'urlScheme': 'agentforge',
            },
            'token': 'nope',
          }),
        ),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('rejects unknown root properties', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': kSyntheticOrigin},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
          'extra': true,
        }),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('rejects non-string fingerprint entries', () {
      expect(
        () => parseAndValidateBuildSafe({
          'schemaVersion': 1,
          'forgejo': {'origin': kSyntheticOrigin},
          'app': {
            'applicationId': 'com.example.agentforge',
            'gradleNamespace': 'dev.agentforge.app',
            'urlScheme': 'agentforge',
          },
          'signing': {
            'androidSha256Fingerprints': [123],
            'appleTeamId': kValidTeamId,
          },
        }),
        throwsA(isA<ConfigValidationException>()),
      );
    });
  });

  group('validateRelease', () {
    test('fails closed on empty signing', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {'androidSha256Fingerprints': <String>[], 'appleTeamId': ''},
      });
      expect(
        () => validateRelease(config),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('fails closed on malformed fingerprint', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {
          'androidSha256Fingerprints': ['AA:BB:CC'],
          'appleTeamId': kValidTeamId,
        },
      });
      expect(
        () => validateRelease(config),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('fails closed on malformed team id', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {
          'androidSha256Fingerprints': [kValidFingerprint],
          'appleTeamId': 'TEAMID12',
        },
      });
      expect(
        () => validateRelease(config),
        throwsA(isA<ConfigValidationException>()),
      );
    });

    test('accepts well-formed signing', () {
      final config = parseAndValidateBuildSafe({
        'schemaVersion': 1,
        'forgejo': {'origin': kSyntheticOrigin},
        'app': {
          'applicationId': 'com.example.agentforge',
          'gradleNamespace': 'dev.agentforge.app',
          'urlScheme': 'agentforge',
        },
        'signing': {
          'androidSha256Fingerprints': [kValidFingerprint],
          'appleTeamId': kValidTeamId,
        },
      });
      expect(() => validateRelease(config), returnsNormally);
    });
  });

  group('renderSelectedDart', () {
    test('emits const AppConfig with synthetic origin', () {
      final config = parseAndValidateBuildSafe(
        loadConfigJson(
          File('${repoRoot.path}/config/agentforge.config.example.json'),
        ),
      );
      final out = renderSelectedDart(config);
      expect(out, contains("defaultBaseUrl = 'https://forge.example.test'"));
      expect(out, contains("trustedHost = 'forge.example.test'"));
      expect(RegExp(r'\btoken\b').hasMatch(out.toLowerCase()), isFalse);
      expect(RegExp(r'\bpassword\b').hasMatch(out.toLowerCase()), isFalse);
      expect(RegExp(r'\bsecret\b').hasMatch(out.toLowerCase()), isFalse);
    });
  });

  group('generate_config CLI (isolated AGENTFORGE_ROOT)', () {
    late Directory fixtureRoot;

    setUp(() {
      fixtureRoot = Directory.systemTemp.createTempSync('af-gen-root-');
      _materializeIsolatedRoot(fixtureRoot, repoRoot);
    });

    tearDown(() {
      if (fixtureRoot.existsSync()) {
        fixtureRoot.deleteSync(recursive: true);
      }
    });

    Map<String, String> env([Map<String, String>? extra]) {
      final m = Map<String, String>.from(Platform.environment)
        ..remove('AGENTFORGE_CONFIG')
        ..['AGENTFORGE_ROOT'] = fixtureRoot.path;
      if (extra != null) m.addAll(extra);
      return m;
    }

    test('build-safe run exits 0 without leaking paths/origin', () {
      final result = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart'],
        workingDirectory: repoRoot.path,
        environment: env(),
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final log = result.stdout.toString();
      expect(log, isNot(contains(fixtureRoot.path)));
      expect(log, isNot(contains(repoRoot.path)));
      expect(log, isNot(contains('origin=')));
    });

    test('--release fails closed without signing fingerprints', () {
      final result = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart', '--release'],
        workingDirectory: repoRoot.path,
        environment: env(),
      );
      expect(result.exitCode, isNot(0));
      final combined = result.stderr.toString() + result.stdout.toString();
      expect(combined, contains('release mode'));
      expect(combined, isNot(contains(fixtureRoot.path)));
    });

    test('missing AGENTFORGE_CONFIG path does not leak absolute path', () {
      final result = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart'],
        workingDirectory: repoRoot.path,
        environment: env({
          'AGENTFORGE_CONFIG': '${fixtureRoot.path}/does-not-exist.json',
        }),
      );
      expect(result.exitCode, isNot(0));
      final err = result.stderr.toString();
      expect(err, contains('missing file'));
      expect(err, isNot(contains(fixtureRoot.path)));
    });

    test(
      'explicit config with synthetic origin never rewrites tracked natives',
      () {
        final trackedProps = File(
          '${fixtureRoot.path}/agentforge-config.properties',
        );
        final trackedXc = File(
          '${fixtureRoot.path}/ios/Flutter/AgentForge.xcconfig',
        );
        final beforeProps = trackedProps.readAsBytesSync();
        final beforeXc = trackedXc.readAsBytesSync();

        final explicit = File('${fixtureRoot.path}/explicit.json')
          ..writeAsStringSync(
            const JsonEncoder.withIndent('  ').convert({
              'schemaVersion': 1,
              'forgejo': {'origin': kSyntheticOrigin},
              'app': {
                'applicationId': 'com.explicit.agentforge',
                'gradleNamespace': 'dev.agentforge.app',
                'urlScheme': 'agentforge',
              },
            }),
          );

        final result = Process.runSync(
          dartBin,
          ['run', 'tool/generate_config.dart'],
          workingDirectory: repoRoot.path,
          environment: env({'AGENTFORGE_CONFIG': explicit.path}),
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(trackedProps.readAsBytesSync(), beforeProps);
        expect(trackedXc.readAsBytesSync(), beforeXc);
        expect(
          File(
            '${fixtureRoot.path}/agentforge-config.local.properties',
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            '${fixtureRoot.path}/ios/Flutter/AgentForge.local.xcconfig',
          ).readAsStringSync().contains('CODE_SIGN_ENTITLEMENTS='),
          isFalse,
        );
      },
    );

    test('default generation is byte-idempotent', () {
      final first = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart'],
        workingDirectory: repoRoot.path,
        environment: env(),
      );
      expect(first.exitCode, 0, reason: first.stderr.toString());

      final props = File('${fixtureRoot.path}/agentforge-config.properties');
      final xc = File('${fixtureRoot.path}/ios/Flutter/AgentForge.xcconfig');
      final selected = File(
        '${fixtureRoot.path}/lib/core/config/generated/app_config.selected.dart',
      );
      final bProps = props.readAsBytesSync();
      final bXc = xc.readAsBytesSync();
      final bSelected = selected.readAsBytesSync();

      final second = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart'],
        workingDirectory: repoRoot.path,
        environment: env(),
      );
      expect(second.exitCode, 0, reason: second.stderr.toString());
      expect(props.readAsBytesSync(), bProps);
      expect(xc.readAsBytesSync(), bXc);
      expect(selected.readAsBytesSync(), bSelected);
    });
  });

  group('committed tracked synthetic generation is byte-idempotent', () {
    test('default generate leaves committed natives unchanged', () {
      // Order-independent: snapshot HEAD bytes via git, generate, compare.
      const propsPath = 'agentforge-config.properties';
      const xcPath = 'ios/Flutter/AgentForge.xcconfig';
      const selectedPath = 'lib/core/config/generated/app_config.selected.dart';

      List<int> headBytes(String rel) {
        final r = Process.runSync('git', [
          'show',
          'HEAD:$rel',
        ], workingDirectory: repoRoot.path);
        expect(r.exitCode, 0, reason: r.stderr.toString());
        final out = r.stdout;
        if (out is List<int>) return out;
        return utf8.encode(out as String);
      }

      // Ensure working tree matches HEAD for these files before generate.
      Process.runSync('git', [
        'checkout',
        'HEAD',
        '--',
        propsPath,
        xcPath,
        selectedPath,
      ], workingDirectory: repoRoot.path);

      final beforeProps = headBytes(propsPath);
      final beforeXc = headBytes(xcPath);
      final beforeSelected = headBytes(selectedPath);

      final env = Map<String, String>.from(Platform.environment)
        ..remove('AGENTFORGE_CONFIG')
        ..remove('AGENTFORGE_ROOT');
      final result = Process.runSync(
        dartBin,
        ['run', 'tool/generate_config.dart'],
        workingDirectory: repoRoot.path,
        environment: env,
      );
      expect(result.exitCode, 0, reason: result.stderr.toString());

      expect(
        File('${repoRoot.path}/$propsPath').readAsBytesSync(),
        beforeProps,
      );
      expect(File('${repoRoot.path}/$xcPath').readAsBytesSync(), beforeXc);
      expect(
        File('${repoRoot.path}/$selectedPath').readAsBytesSync(),
        beforeSelected,
      );
    });
  });
}

void _materializeIsolatedRoot(Directory fixtureRoot, Directory realRepo) {
  for (final rel in [
    'config/agentforge.config.example.json',
    'config/agentforge.config.schema.json',
    'lib/core/config/generated/app_config.selected.dart',
    'agentforge-config.properties',
    'ios/Flutter/AgentForge.xcconfig',
  ]) {
    final from = File('${realRepo.path}/$rel');
    final to = File('${fixtureRoot.path}/$rel');
    to.parent.createSync(recursive: true);
    to.writeAsBytesSync(from.readAsBytesSync());
  }
  Directory('${fixtureRoot.path}/ios/Runner').createSync(recursive: true);
}

File _tempJson(Map<String, dynamic> map) {
  final f = File(
    '${Directory.systemTemp.path}/agentforge-config-test-${map.hashCode}.json',
  );
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
  addTearDown(() {
    if (f.existsSync()) f.deleteSync();
  });
  return f;
}
