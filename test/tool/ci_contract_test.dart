import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/config_model.dart';

void main() {
  final repoRoot = findRepoRoot();

  test('workflow keeps the stable required regression contract', () {
    final workflow = File(
      '${repoRoot.path}/.github/workflows/ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('name: CI'));
    expect(workflow, contains('group: agentforge-ci'));
    expect(workflow, contains('cancel-in-progress: false'));
    expect(workflow, contains("LINE_COVERAGE_FLOOR: '35.5'"));
    expect(workflow, contains("DIFF_COVERAGE_FLOOR: '80'"));
    expect(
      workflow,
      contains('AGENTFORGE_CONFIG: config/agentforge.config.example.json'),
    );
    expect(workflow, contains('persist-credentials: false'));
    expect(workflow, contains('bash tool/ci/setup_flutter.sh'));
    expect(workflow, contains('name: required'));
    expect(workflow, contains('needs: [quality, build_smoke]'));
    // Product steps must go through the local harness (single source of truth).
    expect(workflow, contains('run_local_ci.sh'));
    expect(workflow, contains('bash tool/ci/run_local_ci.sh --lane quality'));
    expect(
      workflow,
      contains('bash tool/ci/run_local_ci.sh --lane build-smoke'),
    );
    // PR/push CI must not install Android SDK packages (nightly only).
    expect(workflow, isNot(contains('setup-android')));
    expect(workflow, isNot(contains('install_android_sdk.sh')));
    expect(workflow, isNot(contains('android-smoke')));
    expect(workflow, isNot(contains('actions/cache@')));

    final harness = File(
      '${repoRoot.path}/tool/ci/run_local_ci.sh',
    ).readAsStringSync();
    expect(harness, contains('run_with_heartbeat.sh'));
    expect(harness, contains('test_heartbeat.sh'));
    expect(harness, contains('setup_flutter.sh'));
    expect(harness, contains('android-smoke'));
    expect(harness, contains('check_diff_coverage.dart'));

    final nightly = File(
      '${repoRoot.path}/.github/workflows/nightly.yml',
    ).readAsStringSync();
    expect(nightly, contains('name: Nightly'));
    expect(nightly, contains('bash tool/ci/setup_flutter.sh'));
    expect(
      nightly,
      contains('bash tool/ci/run_local_ci.sh --lane android-smoke'),
    );
    expect(nightly, contains('setup-android'));

    final flutterBootstrap = File(
      '${repoRoot.path}/tool/ci/setup_flutter.sh',
    ).readAsStringSync();
    expect(flutterBootstrap, contains('FLUTTER_VERSION:=3.44.6'));
    expect(flutterBootstrap, contains('sha256sum --check --status'));
    expect(flutterBootstrap, contains('GITHUB_PATH'));
  });

  test('heartbeat wrapper discovers the real setsid process group', () {
    final wrapper = File(
      '${repoRoot.path}/tool/ci/run_with_heartbeat.sh',
    ).readAsStringSync();

    expect(wrapper, contains('agentforge-pgid.XXXXXX'));
    expect(wrapper, contains('unable to establish command process group'));
    expect(wrapper, contains(r'printf "%s\n" "$$" >"$pgid_file"'));
    expect(wrapper, contains(r'ps -o stat= --pgid "$child_pgid"'));
    expect(wrapper, contains('defer_signal'));
    expect(wrapper, contains('await_child_pgid 100'));
    expect(wrapper, contains('process-group isolation requires setsid'));
    expect(wrapper, isNot(contains('using child PID')));
  });

  test('all workflow actions stay pinned to immutable commit SHAs', () {
    final workflow = File(
      '${repoRoot.path}/.github/workflows/ci.yml',
    ).readAsLinesSync();
    final usesLines = workflow
        .map((line) => line.trim())
        .where((line) => line.startsWith('uses:'))
        .toList();

    expect(usesLines, isNotEmpty);
    for (final line in usesLines) {
      expect(
        RegExp(r'^uses: [^@\s]+@[0-9a-f]{40}(?:\s+#.*)?$').hasMatch(line),
        isTrue,
        reason: 'Action is not pinned to a 40-character commit SHA: $line',
      );
    }
  });

  test('CI shell scripts stay LF-normalized on Windows checkouts', () {
    final attributes = File(
      '${repoRoot.path}/.gitattributes',
    ).readAsStringSync();

    expect(attributes, contains('*.sh text eol=lf'));
  });

  test('shared-runner Gradle bounds cannot silently return to 8 GiB', () {
    final properties = File(
      '${repoRoot.path}/android/gradle.properties',
    ).readAsStringSync();

    expect(properties, contains('-Xmx4G'));
    expect(properties, contains('-XX:MaxMetaspaceSize=1G'));
    expect(properties, contains('org.gradle.workers.max=2'));
    expect(properties, contains('org.gradle.parallel=false'));
    expect(properties, isNot(contains('-Xmx8G')));
  });

  test('config tests never invoke release generation in the real checkout', () {
    final configTests = File(
      '${repoRoot.path}/test/config/generate_config_test.dart',
    ).readAsStringSync();

    expect(
      configTests,
      isNot(contains("['run', 'tool/generate_config.dart', '--release']")),
    );
    expect(configTests, isNot(contains("['checkout', 'HEAD'")));
    expect(configTests, contains('workingDirectory: fixtureRoot.path'));
  });

  test('debug cleartext policy is exact loopback only', () {
    final policy = File(
      '${repoRoot.path}/android/app/src/debug/res/xml/'
      'network_security_config.xml',
    ).readAsStringSync();

    expect(
      RegExp(
        r'<domain includeSubdomains="false">(localhost|127\.0\.0\.1)</domain>',
      ).allMatches(policy).length,
      2,
    );
    expect(policy, isNot(contains('includeSubdomains="true"')));
  });
}
