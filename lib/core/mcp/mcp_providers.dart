import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../agents/agent_models.dart';
import '../agents/agent_providers.dart';
import '../forgejo/forgejo_providers.dart';
import 'mcp_client.dart';
import 'mcp_models.dart';

final mcpClientProvider = Provider<McpClient>((ref) => McpClient());

/// Agents that explicitly claim this PR and have a configured side-car.
///
/// Do not fan private PR identifiers out to unrelated registered endpoints.
/// Linking another endpoint must be an explicit future user action.
final agentsForPrProvider = Provider.autoDispose
    .family<List<AgentEntry>, PrKey>((ref, key) {
      final agents = ref.watch(agentsProvider).valueOrNull ?? const [];
      final work = ref.watch(agentWorkMapProvider).valueOrNull ?? const {};
      final now = DateTime.now().toUtc();
      return agents
          .where(
            (agent) => agentHasFreshClaim(agent, work[agent.id], key, now: now),
          )
          .toList();
    });

final agentContextProvider = FutureProvider.autoDispose
    .family<List<AgentContext>, PrKey>((ref, key) async {
      final workAsync = ref.watch(agentWorkMapProvider);
      final repository = ref.read(agentRepositoryProvider);
      final client = ref.watch(mcpClientProvider);
      final agents = await repository.load();
      final work = workAsync.valueOrNull ?? const {};
      final now = DateTime.now().toUtc();
      final authorized = agents
          .where(
            (agent) => agentHasFreshClaim(agent, work[agent.id], key, now: now),
          )
          .toList();
      if (authorized.isEmpty) return const [];
      final results = await Future.wait(
        authorized.map(
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
    String clientMessageId = '',
  }) async {
    final registeredAgents = await _ref.read(agentRepositoryProvider).load();
    AgentEntry? currentAgent;
    for (final candidate in registeredAgents) {
      if (candidate.id == agent.id) {
        currentAgent = candidate;
        break;
      }
    }
    if (currentAgent == null || !_sameAgentEndpoint(agent, currentAgent)) {
      return FeedbackResult(
        ok: false,
        message: 'Agent endpoint changed. Refresh before sending feedback.',
        clientMessageId: clientMessageId,
      );
    }
    final work = _ref.read(agentWorkMapProvider).valueOrNull ?? const {};
    if (!agentHasFreshClaim(
      currentAgent,
      work[currentAgent.id],
      key,
      now: DateTime.now().toUtc(),
    )) {
      return FeedbackResult(
        ok: false,
        message: 'Agent claim is no longer fresh. Refresh before sending.',
        clientMessageId: clientMessageId,
      );
    }
    final client = _ref.read(mcpClientProvider);
    final result = await client.sendFeedback(
      agent: currentAgent,
      owner: key.owner,
      repo: key.repo,
      prNumber: key.number,
      message: message,
      clientMessageId: clientMessageId,
    );
    if (result.ok) {
      _ref.invalidate(agentContextProvider(key));
    }
    return result;
  }
}

/// Repo → agents with active work on that repo (coordination view).
final coordinationByRepoProvider =
    Provider.autoDispose<
      Map<String, List<({AgentEntry agent, AgentWorkItem work})>>
    >((ref) {
      final agents = ref.watch(agentsProvider).valueOrNull ?? const [];
      final workMap = ref.watch(agentWorkMapProvider).valueOrNull ?? const {};
      final out = <String, List<({AgentEntry agent, AgentWorkItem work})>>{};
      final now = DateTime.now().toUtc();
      for (final agent in agents) {
        final result = workMap[agent.id];
        if (result == null || !agentWorkMatchesEndpoint(agent, result)) {
          continue;
        }
        for (final w in result.items) {
          if (!w.isActiveAt(now)) continue;
          final repo = w.fullName;
          out.putIfAbsent(repo, () => []).add((agent: agent, work: w));
        }
      }
      // sort keys
      final keys = out.keys.toList()..sort();
      return {for (final k in keys) k: out[k]!};
    });

/// Whether retained context belongs to this agent's current endpoint.
bool agentContextMatchesEndpoint(AgentEntry agent, AgentContext context) {
  try {
    return context.sourceEndpoint ==
        normalizeAgentEndpointUrl(agent.mcpBaseUrl);
  } on FormatException {
    return false;
  }
}

/// Authorization check for context reads and feedback writes.
bool agentHasFreshClaim(
  AgentEntry agent,
  AgentWorkResult? result,
  PrKey key, {
  DateTime? now,
}) {
  if (result == null || !agentWorkMatchesEndpoint(agent, result)) return false;
  final checkedAt = now ?? DateTime.now().toUtc();
  return result.items.any(
    (item) =>
        item.owner == key.owner &&
        item.repo == key.repo &&
        item.prNumber == key.number &&
        item.isActiveAt(checkedAt),
  );
}

bool _sameAgentEndpoint(AgentEntry left, AgentEntry right) {
  try {
    return normalizeAgentEndpointUrl(left.mcpBaseUrl) ==
        normalizeAgentEndpointUrl(right.mcpBaseUrl);
  } on FormatException {
    return false;
  }
}
