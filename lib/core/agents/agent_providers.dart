import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agent_models.dart';
import 'agent_repository.dart';
import 'agent_work_client.dart';

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  return AgentRepository();
});

final agentWorkClientProvider = Provider<AgentWorkClient>((ref) {
  return AgentWorkClient();
});

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
    return _ref.read(agentRepositoryProvider).createDraft(
          name: name,
          machine: machine,
          mcpBaseUrl: mcpBaseUrl,
        );
  }
}

/// agentId → active work items (best-effort).
final agentWorkMapProvider =
    FutureProvider.autoDispose<Map<String, List<AgentWorkItem>>>((ref) async {
  final agents = await ref.watch(agentsProvider.future);
  final client = ref.watch(agentWorkClientProvider);
  final out = <String, List<AgentWorkItem>>{};
  await Future.wait(agents.map((a) async {
    out[a.id] = await client.fetchActiveWork(a);
  }));
  return out;
});

/// Reverse index: `"owner/repo#n"` → agents working on it.
final agentsByPrProvider =
    Provider.autoDispose<Map<String, List<AgentEntry>>>((ref) {
  final agents = ref.watch(agentsProvider).valueOrNull ?? const [];
  final work = ref.watch(agentWorkMapProvider).valueOrNull ?? const {};
  final map = <String, List<AgentEntry>>{};
  for (final agent in agents) {
    for (final item in work[agent.id] ?? const <AgentWorkItem>[]) {
      final key = '${item.fullName}#${item.prNumber}';
      map.putIfAbsent(key, () => []).add(agent);
    }
  }
  return map;
});
