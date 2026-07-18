import 'dart:io';

import 'package:agentforge/core/forgejo/forgejo_client.dart';
import 'package:agentforge/core/settings/app_settings.dart';

/// Live demo against a Forgejo instance using the same [ForgejoClient] as the app.
///
/// Defaults to the build's trusted origin ([AppSettings.defaultBaseUrl] —
/// synthetic in committed trees). Override with `FORGEJO_URL` for a private
/// instance. Never embeds a private host literal (AF-012).
Future<void> main(List<String> args) async {
  final token =
      Platform.environment['FORGEJO_TOKEN'] ??
      (args.isNotEmpty ? args.first : '');
  if (token.isEmpty) {
    stderr.writeln(
      'Usage: FORGEJO_TOKEN=... [FORGEJO_URL=...] dart run tool/demo_forgejo.dart',
    );
    exit(2);
  }

  final base =
      Platform.environment['FORGEJO_URL'] ?? AppSettings.defaultBaseUrl;

  stdout.writeln('=== AgentForge live demo ===');
  stdout.writeln('Forgejo: $base');
  stdout.writeln('');

  final client = ForgejoClient(
    settings: AppSettings(baseUrl: base, token: token),
  );

  stdout.writeln('1) whoAmI…');
  final me = await client.whoAmI();
  stdout.writeln('   logged in as: $me');
  stdout.writeln('');

  stdout.writeln('2) list open pull requests…');
  final prs = await client.listOpenPullRequests(limit: 8);
  if (prs.isEmpty) {
    stdout.writeln('   (none open)');
  } else {
    for (final p in prs) {
      final draft = p.draft ? ' [draft]' : '';
      stdout.writeln('   • ${p.fullName}#${p.number}$draft  ${p.title}');
      stdout.writeln('     ${p.htmlUrl}');
    }
  }
  stdout.writeln('');

  if (prs.isEmpty) {
    stdout.writeln('No PR to open for detail demo.');
    return;
  }

  final target = prs.first;
  stdout.writeln('3) get PR detail ${target.fullName}#${target.number}…');
  final detail = await client.getPullRequest(
    owner: target.owner,
    repo: target.repo,
    number: target.number,
  );
  final bodyPreview = detail.body.trim().isEmpty
      ? '(no description)'
      : detail.body.trim().split('\n').take(6).join('\n   ');
  stdout.writeln('   title: ${detail.summary.title}');
  stdout.writeln('   state: ${detail.summary.state}');
  stdout.writeln('   body:\n   $bodyPreview');
  stdout.writeln('');

  stdout.writeln('4) list comments…');
  final comments = await client.listIssueComments(
    owner: target.owner,
    repo: target.repo,
    number: target.number,
  );
  stdout.writeln('   ${comments.length} comment(s)');
  for (final c in comments.take(3)) {
    final who = c.user.login.isEmpty ? '?' : c.user.login;
    final snippet = c.body.trim().replaceAll('\n', ' ');
    final short = snippet.length > 80
        ? '${snippet.substring(0, 80)}…'
        : snippet;
    stdout.writeln('   - $who: $short');
  }
  stdout.writeln('');

  stdout.writeln('5) list formal reviews…');
  final reviews = await client.listPullReviews(
    owner: target.owner,
    repo: target.repo,
    number: target.number,
  );
  stdout.writeln('   ${reviews.length} review(s)');
  for (final r in reviews.take(5)) {
    final who = r.user.login.isEmpty ? '?' : r.user.login;
    stdout.writeln('   - $who: ${r.state}');
  }
  stdout.writeln('');

  stdout.writeln('6) deep-link paths the mobile app would open:');
  stdout.writeln('   route:  ${target.routePath}');
  stdout.writeln(
    '   custom: agentforge://pr/${target.owner}/${target.repo}/${target.number}',
  );
  stdout.writeln('   https:  ${target.htmlUrl}');
  stdout.writeln('');
  stdout.writeln(
    '=== demo complete (read-only; no comments/reviews posted) ===',
  );
}
