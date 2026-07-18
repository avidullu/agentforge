import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'agent_models.dart';

/// Persists the agent registry.
///
/// Uses [SharedPreferences] (not secure storage) because agent metadata is not
/// secret and secure-storage on Flutter **web** is flaky / often fails writes,
/// which made "Add agent" appear to no-op in the Chrome demo.
class AgentRepository {
  AgentRepository({SharedPreferences? prefs, Uuid? uuid})
    : _prefsOverride = prefs,
      _uuid = uuid ?? const Uuid();

  static const _kAgents = 'agent_registry_v1';

  final SharedPreferences? _prefsOverride;
  final Uuid _uuid;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<List<AgentEntry>> load() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_kAgents);
    return AgentEntry.decodeList(raw);
  }

  Future<void> saveAll(List<AgentEntry> agents) async {
    final prefs = await _prefs();
    final ok = await prefs.setString(_kAgents, AgentEntry.encodeList(agents));
    if (!ok) {
      throw StateError('Failed to persist agent registry');
    }
  }

  Future<List<AgentEntry>> upsert(AgentEntry agent) async {
    final list = await load();
    final idx = list.indexWhere((a) => a.id == agent.id);
    if (idx >= 0) {
      list[idx] = agent;
    } else {
      list.add(agent);
    }
    await saveAll(list);
    return list;
  }

  Future<List<AgentEntry>> remove(String id) async {
    final list = await load()
      ..removeWhere((a) => a.id == id);
    await saveAll(list);
    return list;
  }

  AgentEntry createDraft({
    required String name,
    required String machine,
    String mcpBaseUrl = '',
  }) {
    return AgentEntry(
      id: _uuid.v4(),
      name: name,
      machine: machine,
      mcpBaseUrl: mcpBaseUrl,
    );
  }
}
