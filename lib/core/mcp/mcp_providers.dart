import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agents/agent_models.dart';
import '../agents/agent_providers.dart';
import '../forgejo/forgejo_providers.dart';
import 'mcp_client.dart';
import 'mcp_models.dart';

final mcpClientProvider = Provider<McpClient>((ref) => McpClient());

/// Agents that either claim this PR via active-work, or have an MCP URL
/// (so the user can still pull context).
final agentsForPrProvider =
    Provider.autoDispose.family<List<AgentEntry>, PrKey>((ref, key) {
  final agents = ref.watch(agentsProvider).valueOrNull ?? const [];
  final byPr = ref.watch(agentsByPrProvider);
  final claimed = byPr['${key.owner}/${key.repo}#${key.number}'] ?? const [];
  final claimedIds = claimed.map((a) => a.id).toSet();

  final withMcp = agents
      .where((a) => a.mcpBaseUrl.trim().isNotEmpty && !claimedIds.contains(a.id))
      .toList();

  // Prefer claimed agents first, then other MCP-enabled agents.
  return [...claimed, ...withMcp];
});

final agentContextProvider = FutureProvider.autoDispose
    .family<List<AgentContext>, PrKey>((ref, key) async {
  final agents = ref.watch(agentsForPrProvider(key));
  if (agents.isEmpty) return const [];
  final client = ref.watch(mcpClientProvider);
  final results = await Future.wait(
    agents.map(
      (a) => client.fetchContext(
        agent: a,
        owner: key.owner,
        repo: key.repo,
        prNumber: key.number,
      ),
    ),
  );
  return results;
});

final mcpActionsProvider = Provider<McpActions>((ref) => McpActions(ref));

class McpActions {
  McpActions(this._ref);

  final Ref _ref;

  Future<FeedbackResult> sendFeedback({
    required AgentEntry agent,
    required PrKey key,
    required String message,
  }) async {
    final client = _ref.read(mcpClientProvider);
    final result = await client.sendFeedback(
      agent: agent,
      owner: key.owner,
      repo: key.repo,
      prNumber: key.number,
      message: message,
    );
    if (result.ok) {
      _ref.invalidate(agentContextProvider(key));
    }
    return result;
  }
}

/// Repo → agents with active work on that repo (coordination view).
final coordinationByRepoProvider =
    Provider.autoDispose<Map<String, List<({AgentEntry agent, AgentWorkItem work})>>>((ref) {
  final agents = ref.watch(agentsProvider).valueOrNull ?? const [];
  final workMap = ref.watch(agentWorkMapProvider).valueOrNull ?? const {};
  final out = <String, List<({AgentEntry agent, AgentWorkItem work})>>{};
  for (final agent in agents) {
    for (final w in workMap[agent.id] ?? const <AgentWorkItem>[]) {
      final repo = w.fullName;
      out.putIfAbsent(repo, () => []).add((agent: agent, work: w));
    }
  }
  // sort keys
  final keys = out.keys.toList()..sort();
  return {for (final k in keys) k: out[k]!};
});
