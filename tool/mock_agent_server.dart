// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Minimal AgentForge side-car for local demos.
///
///   dart run tool/mock_agent_server.dart [port]
///
/// Endpoints: /active-work, /context, /feedback, /mcp
Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.parse(args.first) : 8765;
  final feedbackLog = <String>[];
  final feedbackById = <String, String>{};

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('Mock agent listening on http://127.0.0.1:$port');
  print('Register in AgentForge Agents with this side-car URL.');

  await for (final request in server) {
    try {
      await _handle(request, feedbackLog, feedbackById);
    } catch (e, st) {
      print('Error: $e\n$st');
      request.response.statusCode = 500;
      request.response.write('error');
      await request.response.close();
    }
  }
}

Future<void> _handle(
  HttpRequest request,
  List<String> feedbackLog,
  Map<String, String> feedbackById,
) async {
  // CORS for Chrome demo
  request.response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type, Accept');

  if (request.method == 'OPTIONS') {
    request.response.statusCode = 204;
    await request.response.close();
    return;
  }

  final path = request.uri.path;
  if (path == '/active-work' && request.method == 'GET') {
    _json(request, [
      {
        'repo': 'Khelsutra/badminton-highlight-indexer',
        'pr_number': 623,
        'branch': 'docs/golden-eval',
        'title': 'docs: first human-golden eval report',
        'status': 'in_progress',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      {
        'repo': 'Khelsutra/rally-corpus-vault',
        'pr_number': 25,
        'branch': 'fix/post-review',
        'title': 'fix: post-review polish',
        'status': 'in_progress',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    ]);
    return;
  }

  if (path == '/context' && request.method == 'GET') {
    final owner = request.uri.queryParameters['owner'] ?? '';
    final repo = request.uri.queryParameters['repo'] ?? '';
    final pr = request.uri.queryParameters['pr'] ?? '';
    _json(request, {
      'plan':
          '1) Land remaining review notes on $owner/$repo#$pr\n'
          '2) Keep CI green\n'
          '3) Hand off for owner merge',
      'rationale_summary':
          'Mock agent: focusing on docs/test polish. '
          'Feedback count so far: ${feedbackLog.length}.',
      'recent_actions': [
        'Opened $owner/$repo#$pr context',
        'Skimmed conversation',
        if (feedbackLog.isNotEmpty) 'Last feedback: ${feedbackLog.last}',
      ],
      'status': 'in_progress',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return;
  }

  if (path == '/feedback' && request.method == 'POST') {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final msg = (data['message'] ?? '').toString();
    final clientMessageId = (data['client_message_id'] ?? '').toString();
    final idempotencyKey = (data['idempotency_key'] ?? '').toString();
    if (clientMessageId.isEmpty || idempotencyKey != clientMessageId) {
      request.response.statusCode = HttpStatus.badRequest;
      _json(request, {
        'ok': false,
        'message': 'Matching client_message_id and idempotency_key required',
      });
      return;
    }
    final signature = jsonEncode({
      'owner': data['owner'],
      'repo': data['repo'],
      'pr': data['pr'],
      'message': msg,
    });
    final prior = feedbackById[clientMessageId];
    if (prior != null && prior != signature) {
      request.response.statusCode = HttpStatus.conflict;
      _json(request, {
        'ok': false,
        'message': 'Idempotency key was already used for another payload',
      });
      return;
    }
    final duplicate = prior == signature;
    if (!duplicate) {
      feedbackById[clientMessageId] = signature;
      feedbackLog.add(msg);
      print('Feedback: $msg');
    }
    _json(request, {
      'ok': true,
      'message': duplicate
          ? 'already queued (${feedbackLog.length})'
          : 'queued (${feedbackLog.length})',
      'delivery_id': clientMessageId,
    });
    return;
  }

  if (path == '/mcp' && request.method == 'POST') {
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final id = data['id'];
    final method = data['method'];
    if (method == 'resources/read') {
      _json(request, {
        'jsonrpc': '2.0',
        'id': id,
        'result': {
          'contents': [
            {
              'uri': (data['params'] as Map?)?['uri'],
              'text': jsonEncode({
                'plan': 'MCP resource plan',
                'rationale_summary': 'via resources/read',
                'recent_actions': ['mcp read'],
                'status': 'in_progress',
              }),
            },
          ],
        },
      });
      return;
    }
    if (method == 'tools/call') {
      final args = (data['params'] as Map?)?['arguments'] as Map? ?? {};
      feedbackLog.add((args['message'] ?? '').toString());
      _json(request, {
        'jsonrpc': '2.0',
        'id': id,
        'result': {'message': 'mcp feedback accepted'},
      });
      return;
    }
    _json(request, {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': -32601, 'message': 'Method not found'},
    });
    return;
  }

  request.response.statusCode = 404;
  request.response.write('not found');
  await request.response.close();
}

void _json(HttpRequest request, Object data) {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(data));
  request.response.close();
}
