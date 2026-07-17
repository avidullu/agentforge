import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart';
import 'forgejo_client.dart';
import 'models.dart';

final forgejoClientProvider = FutureProvider<ForgejoClient?>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  if (!settings.isConfigured) return null;
  return ForgejoClient(settings: settings);
});

/// Open PRs from the configured Forgejo instance.
final openPullRequestsProvider =
    FutureProvider.autoDispose<List<PullRequestSummary>>((ref) async {
  final client = await ref.watch(forgejoClientProvider.future);
  if (client == null) {
    throw const _NotConfigured();
  }
  return client.listOpenPullRequests();
});

class PrKey {
  const PrKey(this.owner, this.repo, this.number);

  final String owner;
  final String repo;
  final int number;

  @override
  bool operator ==(Object other) =>
      other is PrKey &&
      other.owner == owner &&
      other.repo == repo &&
      other.number == number;

  @override
  int get hashCode => Object.hash(owner, repo, number);
}

final pullRequestDetailProvider =
    FutureProvider.autoDispose.family<PullRequestDetail?, PrKey>((ref, key) async {
  final client = await ref.watch(forgejoClientProvider.future);
  if (client == null) return null;
  return client.getPullRequest(
    owner: key.owner,
    repo: key.repo,
    number: key.number,
  );
});

class _NotConfigured implements Exception {
  const _NotConfigured();

  @override
  String toString() => 'Forgejo is not configured. Open Settings to add a token.';
}
