import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/agents/agent_models.dart';
import 'package:agentforge/core/agents/agent_providers.dart';
import 'package:agentforge/core/agents/agent_repository.dart';
import 'package:agentforge/core/forgejo/forgejo_providers.dart';
import 'package:agentforge/core/mcp/mcp_client.dart';
import 'package:agentforge/core/mcp/mcp_models.dart';
import 'package:agentforge/core/mcp/mcp_providers.dart';

class _AgentRepository extends AgentRepository {
  _AgentRepository(this.agents);

  final List<AgentEntry> agents;

  @override
  Future<List<AgentEntry>> load() async => agents;
}

class _RecordingMcpClient extends McpClient {
  int contextCalls = 0;
  int feedbackCalls = 0;

  @override
  Future<AgentContext> fetchContext({
    required AgentEntry agent,
    required String owner,
    required String repo,
    required int prNumber,
  }) async {
    contextCalls += 1;
    return AgentContext(
      agentId: agent.id,
      agentName: agent.name,
      sourceEndpoint: agent.mcpBaseUrl,
    );
  }

  @override
  Future<FeedbackResult> sendFeedback({
    required AgentEntry agent,
    required String owner,
    required String repo,
    required int prNumber,
    required String message,
    String clientMessageId = '',
  }) async {
    feedbackCalls += 1;
    return const FeedbackResult(ok: true, deliveryId: 'receipt');
  }
}

void main() {
  test(
    'PR context is limited to explicitly claimed side-car endpoints',
    () async {
      const claimed = AgentEntry(
        id: 'claimed',
        name: 'Codex',
        machine: 'msi',
        mcpBaseUrl: 'https://codex.tail.example',
      );
      const noSidecar = AgentEntry(
        id: 'no-sidecar',
        name: 'Claude',
        machine: 'pbook',
      );
      const unrelated = AgentEntry(
        id: 'unrelated',
        name: 'Gemini',
        machine: 'cloud',
        mcpBaseUrl: 'https://gemini.example',
      );
      final claimedWork = AgentWorkResult.available([
        AgentWorkItem(
          owner: 'o',
          repo: 'r',
          prNumber: 1,
          updatedAt: DateTime.now().toUtc(),
        ),
      ], sourceEndpoint: 'https://codex.tail.example');
      final container = ProviderContainer(
        overrides: [
          agentsProvider.overrideWith(
            (ref) async => [claimed, noSidecar, unrelated],
          ),
          agentWorkMapProvider.overrideWith(
            (ref) async => {'claimed': claimedWork},
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(agentsProvider.future);
      await container.read(agentWorkMapProvider.future);

      expect(container.read(agentsForPrProvider(const PrKey('o', 'r', 1))), [
        claimed,
      ]);
      expect(
        container.read(agentsForPrProvider(const PrKey('o', 'r', 2))),
        isEmpty,
      );
    },
  );

  test('retained coordination work cannot transfer across endpoints', () async {
    const editedAgent = AgentEntry(
      id: 'same-id',
      name: 'Edited',
      machine: 'msi',
      mcpBaseUrl: 'https://new-agent.example',
    );
    final oldWork = AgentWorkResult.available([
      AgentWorkItem(
        owner: 'private',
        repo: 'repo',
        prNumber: 7,
        updatedAt: DateTime.now().toUtc(),
      ),
    ], sourceEndpoint: 'https://old-agent.example');
    final container = ProviderContainer(
      overrides: [
        agentsProvider.overrideWith((ref) async => [editedAgent]),
        agentWorkMapProvider.overrideWith((ref) async => {'same-id': oldWork}),
      ],
    );
    addTearDown(container.dispose);

    await container.read(agentsProvider.future);
    await container.read(agentWorkMapProvider.future);

    expect(container.read(coordinationByRepoProvider), isEmpty);
  });

  test('retained context must match the current endpoint identity', () {
    const agent = AgentEntry(
      id: 'same-id',
      name: 'Edited',
      machine: 'msi',
      mcpBaseUrl: 'https://new-agent.example/',
    );
    const oldContext = AgentContext(
      agentId: 'same-id',
      agentName: 'Old',
      sourceEndpoint: 'https://old-agent.example',
    );
    const currentContext = AgentContext(
      agentId: 'same-id',
      agentName: 'Edited',
      sourceEndpoint: 'https://new-agent.example',
    );

    expect(agentContextMatchesEndpoint(agent, oldContext), isFalse);
    expect(agentContextMatchesEndpoint(agent, currentContext), isTrue);
  });

  test('stale heartbeat blocks context reads and feedback writes', () async {
    const agent = AgentEntry(
      id: 'agent',
      name: 'Codex',
      machine: 'msi',
      mcpBaseUrl: 'https://agent.example',
    );
    const key = PrKey('private', 'repo', 7);
    final staleWork = AgentWorkResult.available([
      AgentWorkItem(
        owner: 'private',
        repo: 'repo',
        prNumber: 7,
        updatedAt: DateTime.now().toUtc().subtract(const Duration(minutes: 6)),
      ),
    ], sourceEndpoint: 'https://agent.example');
    final client = _RecordingMcpClient();
    final container = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(_AgentRepository([agent])),
        agentsProvider.overrideWith((ref) async => [agent]),
        agentWorkMapProvider.overrideWith((ref) async => {'agent': staleWork}),
        mcpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    await container.read(agentWorkMapProvider.future);

    final contexts = await container.read(agentContextProvider(key).future);
    final feedback = await container
        .read(mcpActionsProvider)
        .sendFeedback(agent: agent, key: key, message: 'do not deliver');

    expect(contexts, isEmpty);
    expect(feedback.ok, isFalse);
    expect(client.contextCalls, 0);
    expect(client.feedbackCalls, 0);
  });

  test('fresh exact claim authorizes context and feedback', () async {
    const agent = AgentEntry(
      id: 'agent',
      name: 'Codex',
      machine: 'msi',
      mcpBaseUrl: 'https://agent.example',
    );
    const key = PrKey('o', 'r', 1);
    final freshWork = AgentWorkResult.available([
      AgentWorkItem(
        owner: 'o',
        repo: 'r',
        prNumber: 1,
        updatedAt: DateTime.now().toUtc(),
      ),
    ], sourceEndpoint: 'https://agent.example');
    final client = _RecordingMcpClient();
    final container = ProviderContainer(
      overrides: [
        agentRepositoryProvider.overrideWithValue(_AgentRepository([agent])),
        agentsProvider.overrideWith((ref) async => [agent]),
        agentWorkMapProvider.overrideWith((ref) async => {'agent': freshWork}),
        mcpClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    await container.read(agentWorkMapProvider.future);

    final contexts = await container.read(agentContextProvider(key).future);
    final feedback = await container
        .read(mcpActionsProvider)
        .sendFeedback(agent: agent, key: key, message: 'deliver');

    expect(contexts, hasLength(1));
    expect(feedback.ok, isTrue);
    expect(client.contextCalls, 1);
    expect(client.feedbackCalls, 1);
  });
}
