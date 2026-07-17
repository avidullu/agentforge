import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'agent_models.dart';

class AgentRepository {
  AgentRepository({FlutterSecureStorage? storage, Uuid? uuid})
      : _storage = storage ?? const FlutterSecureStorage(),
        _uuid = uuid ?? const Uuid();

  static const _kAgents = 'agent_registry_v1';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  Future<List<AgentEntry>> load() async {
    final raw = await _storage.read(key: _kAgents);
    return AgentEntry.decodeList(raw);
  }

  Future<void> saveAll(List<AgentEntry> agents) async {
    await _storage.write(key: _kAgents, value: AgentEntry.encodeList(agents));
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
    final list = await load()..removeWhere((a) => a.id == id);
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
