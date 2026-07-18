import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentforge/core/agents/agent_models.dart';
import 'package:agentforge/core/mcp/mcp_client.dart';
import 'package:agentforge/core/mcp/mcp_models.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final ResponseBody Function(RequestOptions) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.followRedirects, isFalse);
    return handler(options);
  }
}

void main() {
  const agent = AgentEntry(
    id: 'a1',
    name: 'MockCodex',
    machine: 'msi',
    mcpBaseUrl: 'http://127.0.0.1:8765',
  );

  test('fetchContext maps REST payload', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.path, 'http://127.0.0.1:8765/context');
      expect(options.queryParameters['pr'], 42);
      return ResponseBody.fromString(
        '''
        {
          "plan": "Do the thing",
          "reasoning": "Because",
          "recent_actions": ["edit", "test"],
          "status": "in_progress",
          "updated_at": "2026-07-18T00:00:00Z"
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final client = McpClient(dio: dio);
    final ctx = await client.fetchContext(
      agent: agent,
      owner: 'o',
      repo: 'r',
      prNumber: 42,
    );
    expect(ctx.plan, 'Do the thing');
    expect(ctx.recentActions, ['edit', 'test']);
    expect(ctx.error, isNull);
    expect(ctx.sourceEndpoint, 'http://127.0.0.1:8765');
  });

  test('sendFeedback posts REST body', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.method, 'POST');
      expect(options.path, 'http://127.0.0.1:8765/feedback');
      final data = options.data as Map<String, dynamic>;
      expect(data['owner'], 'o');
      expect(data['repo'], 'r');
      expect(data['pr'], 1);
      expect(data['message'], 'LGTM direction');
      expect(data['client_message_id'], isNotEmpty);
      expect(data['idempotency_key'], data['client_message_id']);
      return ResponseBody.fromString(
        '{"ok":true,"message":"queued","delivery_id":"d-1"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final client = McpClient(dio: dio);
    final r = await client.sendFeedback(
      agent: agent,
      owner: 'o',
      repo: 'r',
      prNumber: 1,
      message: 'LGTM direction',
    );
    expect(r.ok, isTrue);
    expect(r.message, 'queued');
    expect(r.clientMessageId, isNotEmpty);
    expect(r.deliveryId, 'd-1');
  });

  test('sendFeedback does not retry an ambiguous failed write', () async {
    var calls = 0;
    final dio = Dio();
    dio.httpClientAdapter = _Adapter((options) {
      calls += 1;
      return ResponseBody.fromString(
        '{"message":"accepted but response was invalid"}',
        502,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final client = McpClient(dio: dio);
    final result = await client.sendFeedback(
      agent: agent,
      owner: 'o',
      repo: 'r',
      prNumber: 1,
      message: 'one delivery only',
    );

    expect(result.ok, isFalse);
    expect(calls, 1);
  });

  test('sendFeedback reuses a supplied idempotency key', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter((options) {
      final data = options.data as Map<String, dynamic>;
      expect(data['client_message_id'], 'stable-message-1');
      expect(data['idempotency_key'], 'stable-message-1');
      return ResponseBody.fromString(
        '{"ok":true,"delivery_id":"delivery-1"}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final result = await McpClient(dio: dio).sendFeedback(
      agent: agent,
      owner: 'o',
      repo: 'r',
      prNumber: 1,
      message: 'retry me safely',
      clientMessageId: 'stable-message-1',
    );

    expect(result.ok, isTrue);
    expect(result.clientMessageId, 'stable-message-1');
    expect(result.deliveryId, 'delivery-1');
  });

  test(
    'sendFeedback requires a delivery receipt before clearing a draft',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = _Adapter(
        (_) => ResponseBody.fromString(
          '{"ok":true,"message":"accepted"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      final result = await McpClient(dio: dio).sendFeedback(
        agent: agent,
        owner: 'o',
        repo: 'r',
        prNumber: 1,
        message: 'keep this draft',
      );

      expect(result.ok, isFalse);
      expect(result.clientMessageId, isNotEmpty);
      expect(result.deliveryId, isEmpty);
      expect(result.message, contains('without a delivery receipt'));
    },
  );

  test('sendFeedback rejects a non-string delivery receipt', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter(
      (_) => ResponseBody.fromString(
        '{"ok":true,"delivery_id":123}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    final result = await McpClient(dio: dio).sendFeedback(
      agent: agent,
      owner: 'o',
      repo: 'r',
      prNumber: 1,
      message: 'retain this draft',
    );

    expect(result.ok, isFalse);
    expect(result.clientMessageId, isNotEmpty);
    expect(result.deliveryId, isEmpty);
  });

  test('non-loopback agent endpoints require HTTPS', () async {
    const insecureAgent = AgentEntry(
      id: 'a2',
      name: 'RemoteCodex',
      machine: 'msi',
      mcpBaseUrl: 'http://100.64.0.10:8765',
    );
    final result = await McpClient().sendFeedback(
      agent: insecureAgent,
      owner: 'o',
      repo: 'r',
      prNumber: 1,
      message: 'hello',
    );

    expect(result.ok, isFalse);
    expect(result.message, contains('HTTPS'));
  });

  test('loopback-looking DNS names cannot bypass HTTPS', () async {
    const deceptiveAgent = AgentEntry(
      id: 'a3',
      name: 'Deceptive',
      machine: 'remote',
      mcpBaseUrl: 'http://127.evil.example:8765',
    );

    final result = await McpClient().sendFeedback(
      agent: deceptiveAgent,
      owner: 'o',
      repo: 'r',
      prNumber: 1,
      message: 'must not leave over cleartext',
    );

    expect(result.ok, isFalse);
    expect(result.message, contains('HTTPS'));
  });

  test('AgentContext.fromJson parses actions maps', () {
    final c = AgentContext.fromJson(
      {
        'plan': 'p',
        'recent_actions': [
          {'summary': 'ran tests'},
          'committed',
        ],
      },
      agentId: '1',
      agentName: 'x',
    );
    expect(c.recentActions, ['ran tests', 'committed']);
  });
}
