import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentforge/core/agents/agent_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('upsert and load agents via SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = AgentRepository(prefs: prefs);

    expect(await repo.load(), isEmpty);

    final a = repo.createDraft(
      name: 'Codex',
      machine: 'msi',
      mcpBaseUrl: 'http://127.0.0.1:8765',
    );
    await repo.upsert(a);

    final loaded = await repo.load();
    expect(loaded, hasLength(1));
    expect(loaded.first.name, 'Codex');
    expect(loaded.first.mcpBaseUrl, 'http://127.0.0.1:8765');

    await repo.upsert(a.copyWith(name: 'Codex2'));
    final updated = await repo.load();
    expect(updated, hasLength(1));
    expect(updated.first.name, 'Codex2');

    await repo.remove(a.id);
    expect(await repo.load(), isEmpty);
  });
}
