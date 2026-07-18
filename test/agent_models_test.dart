import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/agents/agent_models.dart';

void main() {
  test('AgentEntry round-trips JSON list', () {
    const a = AgentEntry(
      id: '1',
      name: 'Codex',
      machine: 'avis-msi',
      mcpBaseUrl: 'http://100.1.2.3:8765',
    );
    final raw = AgentEntry.encodeList([a]);
    final list = AgentEntry.decodeList(raw);
    expect(list, hasLength(1));
    expect(list.first.name, 'Codex');
    expect(list.first.mcpBaseUrl, 'http://100.1.2.3:8765');
  });

  test('AgentWorkItem parses repo string', () {
    final w = AgentWorkItem.fromJson({
      'repo': 'Khelsutra/badminton-highlight-indexer',
      'pr_number': 611,
      'title': 'fix',
      'status': 'in_progress',
      'updated_at': '2026-07-18T12:00:00Z',
    });
    expect(w.owner, 'Khelsutra');
    expect(w.repo, 'badminton-highlight-indexer');
    expect(w.prNumber, 611);
    expect(w.updatedAt, DateTime.utc(2026, 7, 18, 12));
    expect(w.isActiveAt(DateTime.utc(2026, 7, 18, 12, 4)), isTrue);
    expect(w.isActiveAt(DateTime.utc(2026, 7, 18, 12, 6)), isFalse);
  });

  test('AgentWorkItem requires an active state and heartbeat', () {
    final completed = AgentWorkItem.fromJson({
      'repo': 'o/r',
      'pr_number': 1,
      'status': 'completed',
      'updated_at': '2026-07-18T12:00:00Z',
    });
    final missingHeartbeat = AgentWorkItem.fromJson({
      'repo': 'o/r',
      'pr_number': 2,
      'status': 'in_progress',
    });

    expect(completed.isActiveAt(DateTime.utc(2026, 7, 18, 12, 1)), isFalse);
    expect(
      missingHeartbeat.isActiveAt(DateTime.utc(2026, 7, 18, 12, 1)),
      isFalse,
    );
  });
}
