import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mcp/mcp_client.dart';
import 'agent_models.dart';
import 'agent_repository.dart';
import 'agent_work_client.dart';

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return AgentRepository();
});

final agentWorkClientProvider = Provider<AgentWorkClient>((ref) {
  return AgentWorkClient();
});

/// Polling also bounds how long a once-fresh claim can remain cached.
final agentWorkRefreshIntervalProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 1),
);

final agentsProvider = FutureProvider<List<AgentEntry>>((ref) async {
  return ref.watch(agentRepositoryProvider).load();
});

final agentControllerProvider = Provider<AgentController>((ref) {
  return AgentController(ref);
});

class AgentController {
  AgentController(this._ref);

  final Ref _ref;

  Future<void> upsert(AgentEntry agent) async {
    await _ref.read(agentRepositoryProvider).upsert(agent);
    _ref.invalidate(agentsProvider);
    _ref.invalidate(agentWorkMapProvider);
  }

  Future<void> remove(String id) async {
    await _ref.read(agentRepositoryProvider).remove(id);
    _ref.invalidate(agentsProvider);
    _ref.invalidate(agentWorkMapProvider);
  }

  AgentEntry draft({
    required String name,
    required String machine,
    String mcpBaseUrl = '',
  }) {
    return _ref
        .read(agentRepositoryProvider)
        .createDraft(name: name, machine: machine, mcpBaseUrl: mcpBaseUrl);
  }
}

/// agentId → typed endpoint activity result.
final agentWorkMapProvider =
    FutureProvider.autoDispose<Map<String, AgentWorkResult>>((ref) async {
      Timer? refreshTimer;
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        refreshTimer?.cancel();
      });
      final agents = await ref.watch(agentsProvider.future);
      final client = ref.watch(agentWorkClientProvider);
      final refreshInterval = ref.watch(agentWorkRefreshIntervalProvider);
      final out = <String, AgentWorkResult>{};
      await Future.wait(
        agents.map((a) async {
          out[a.id] = await client.fetchActiveWork(a);
        }),
      );
      if (!disposed) {
        var nextRefresh = refreshInterval;
        final now = DateTime.now().toUtc();
        for (final result in out.values) {
          for (final item in result.items) {
            final updatedAt = item.updatedAt;
            if (updatedAt == null) continue;
            final untilExpiry = updatedAt
                .toUtc()
                .add(const Duration(minutes: 5))
                .difference(now);
            if (!untilExpiry.isNegative && untilExpiry < nextRefresh) {
              nextRefresh = untilExpiry + const Duration(milliseconds: 1);
            }
          }
        }
        refreshTimer = Timer(nextRefresh, ref.invalidateSelf);
      }
      return out;
    });

/// Reverse index: `"owner/repo#n"` → agents working on it.
final agentsByPrProvider = Provider.autoDispose<Map<String, List<AgentEntry>>>((
  ref,
) {
  final agents = ref.watch(agentsProvider).valueOrNull ?? const [];
  final work = ref.watch(agentWorkMapProvider).valueOrNull ?? const {};
  final now = DateTime.now().toUtc();
  final map = <String, List<AgentEntry>>{};
  for (final agent in agents) {
    final result = work[agent.id];
    if (result == null || !agentWorkMatchesEndpoint(agent, result)) continue;
    for (final item in result.items) {
      if (!item.isActiveAt(now)) continue;
      final key = '${item.fullName}#${item.prNumber}';
      map.putIfAbsent(key, () => []).add(agent);
    }
  }
  return map;
});

/// Whether cached activity was produced by this agent's current endpoint.
///
/// Riverpod deliberately retains previous async values during refresh. The
/// endpoint identity check prevents an edited entry that reused an ID from
/// inheriting the prior endpoint's private repository claims.
bool agentWorkMatchesEndpoint(AgentEntry agent, AgentWorkResult result) {
  try {
    return result.sourceEndpoint == normalizeAgentEndpointUrl(agent.mcpBaseUrl);
  } on FormatException {
    return false;
  }
}
