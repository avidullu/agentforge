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

final issueCommentsProvider =
    FutureProvider.autoDispose.family<List<IssueComment>, PrKey>((ref, key) async {
  final client = await ref.watch(forgejoClientProvider.future);
  if (client == null) return const [];
  return client.listIssueComments(
    owner: key.owner,
    repo: key.repo,
    number: key.number,
  );
});

final pullReviewsProvider =
    FutureProvider.autoDispose.family<List<PullReview>, PrKey>((ref, key) async {
  final client = await ref.watch(forgejoClientProvider.future);
  if (client == null) return const [];
  return client.listPullReviews(
    owner: key.owner,
    repo: key.repo,
    number: key.number,
  );
});

final prActionsProvider = Provider<PrActions>((ref) => PrActions(ref));

class PrActions {
  PrActions(this._ref);

  final Ref _ref;

  Future<ForgejoClient> _requireClient() async {
    final client = await _ref.read(forgejoClientProvider.future);
    if (client == null) {
      throw const _NotConfigured();
    }
    return client;
  }

  Future<void> postComment(PrKey key, String body) async {
    final client = await _requireClient();
    await client.createIssueComment(
      owner: key.owner,
      repo: key.repo,
      number: key.number,
      body: body,
    );
    _ref.invalidate(issueCommentsProvider(key));
  }

  Future<void> submitReview(
    PrKey key, {
    required ReviewEvent event,
    String body = '',
  }) async {
    final client = await _requireClient();
    await client.createPullReview(
      owner: key.owner,
      repo: key.repo,
      number: key.number,
      event: event,
      body: body,
    );
    _ref.invalidate(pullReviewsProvider(key));
    _ref.invalidate(issueCommentsProvider(key));
  }
}

class _NotConfigured implements Exception {
  const _NotConfigured();

  @override
  String toString() => 'Forgejo is not configured. Open Settings to add a token.';
}
