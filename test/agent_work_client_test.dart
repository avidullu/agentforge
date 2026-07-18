import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/agents/agent_models.dart';
import 'package:agentforge/core/agents/agent_providers.dart';
import 'package:agentforge/core/agents/agent_work_client.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);

  final String body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.followRedirects, isFalse);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _CountingWorkClient extends AgentWorkClient {
  int calls = 0;

  @override
  Future<AgentWorkResult> fetchActiveWork(AgentEntry agent) async {
    calls += 1;
    return AgentWorkResult.available([
      AgentWorkItem(
        owner: 'o',
        repo: 'r',
        prNumber: 1,
        updatedAt: DateTime.now().toUtc(),
      ),
    ], sourceEndpoint: agent.mcpBaseUrl);
  }
}

void main() {
  test('unconfigured endpoint is distinct from verified idle', () async {
    const agent = AgentEntry(id: 'a', name: 'A', machine: 'm');

    final result = await AgentWorkClient().fetchActiveWork(agent);

    expect(result.endpointConfigured, isFalse);
    expect(result.error, isNull);
    expect(result.items, isEmpty);
  });

  test('malformed activity is unavailable rather than idle', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter('["malformed"]');
    const agent = AgentEntry(
      id: 'a',
      name: 'A',
      machine: 'm',
      mcpBaseUrl: 'http://127.0.0.1:8765',
    );

    final result = await AgentWorkClient(dio: dio).fetchActiveWork(agent);

    expect(result.endpointConfigured, isTrue);
    expect(result.isUnavailable, isTrue);
    expect(result.error, contains('Invalid active-work item'));
    expect(result.items, isEmpty);
  });

  test('missing state or heartbeat cannot become PR provenance', () async {
    const payloads = [
      '[{"repo":"o/r","pr_number":1,"updated_at":"2026-07-18T12:00:00Z"}]',
      '[{"repo":"o/r","pr_number":1,"status":"in_progress"}]',
      '[{"repo":"o/r","pr_number":1,"status":"in_progress","updated_at":"not-a-date"}]',
      '[{"repo":"o/r","pr_number":1.9,"status":"in_progress","updated_at":"2026-07-18T12:00:00Z"}]',
      '[{"repo":"o/r/extra","pr_number":1,"status":"in_progress","updated_at":"2026-07-18T12:00:00Z"}]',
    ];
    const agent = AgentEntry(
      id: 'a',
      name: 'A',
      machine: 'm',
      mcpBaseUrl: 'http://127.0.0.1:8765',
    );

    for (final payload in payloads) {
      final dio = Dio()..httpClientAdapter = _Adapter(payload);
      final result = await AgentWorkClient(dio: dio).fetchActiveWork(agent);
      expect(result.isUnavailable, isTrue, reason: payload);
      expect(result.items, isEmpty, reason: payload);
    }
  });

  test('active-work refresh timer revalidates cached claims', () async {
    const agent = AgentEntry(
      id: 'a',
      name: 'A',
      machine: 'm',
      mcpBaseUrl: 'https://agent.example',
    );
    final client = _CountingWorkClient();
    final container = ProviderContainer(
      overrides: [
        agentsProvider.overrideWith((ref) async => [agent]),
        agentWorkClientProvider.overrideWithValue(client),
        agentWorkRefreshIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    final subscription = container.listen(
      agentWorkMapProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(() {
      subscription.close();
      container.dispose();
    });

    await container.read(agentWorkMapProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(client.calls, greaterThan(1));
  });

  test('retained work cannot transfer to an edited agent endpoint', () async {
    const editedAgent = AgentEntry(
      id: 'same-id',
      name: 'Edited',
      machine: 'm',
      mcpBaseUrl: 'https://new-agent.example',
    );
    final staleResult = AgentWorkResult.available([
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
        agentWorkMapProvider.overrideWith(
          (ref) async => {'same-id': staleResult},
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(agentsProvider.future);
    await container.read(agentWorkMapProvider.future);

    expect(container.read(agentsByPrProvider), isEmpty);
  });
}
