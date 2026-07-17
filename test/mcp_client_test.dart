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
  });

  test('sendFeedback posts REST body', () async {
    final dio = Dio();
    dio.httpClientAdapter = _Adapter((options) {
      expect(options.method, 'POST');
      expect(options.path, 'http://127.0.0.1:8765/feedback');
      return ResponseBody.fromString(
        '{"ok":true,"message":"queued"}',
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
