import 'dart:convert';

import 'package:dio/dio.dart';

import '../agents/agent_models.dart';
import 'mcp_models.dart';

/// Thin client for AgentForge agent side-cars.
///
/// **Preferred HTTP contract** (easy for wrappers):
/// - `GET  {base}/active-work`
/// - `GET  {base}/context?owner=&repo=&pr=`
/// - `POST {base}/feedback`  body: `{owner,repo,pr,message}`
///
/// **Optional MCP JSON-RPC** at `{base}/mcp`:
/// - `resources/read` uri `agentforge://context/{owner}/{repo}/{pr}`
/// - `tools/call` name `send_feedback`
class McpClient {
  McpClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 12),
                headers: {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;
  int _rpcId = 1;

  String _root(String base) {
    var b = base.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  Future<AgentContext> fetchContext({
    required AgentEntry agent,
    required String owner,
    required String repo,
    required int prNumber,
  }) async {
    final base = _root(agent.mcpBaseUrl);
    if (base.isEmpty) {
      return AgentContext.unavailable(
        agentId: agent.id,
        agentName: agent.name,
        error: 'No MCP base URL configured',
      );
    }

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$base/context',
        queryParameters: {
          'owner': owner,
          'repo': repo,
          'pr': prNumber,
        },
      );
      if (res.data != null) {
        return AgentContext.fromJson(
          res.data!,
          agentId: agent.id,
          agentName: agent.name,
          source: 'http',
        );
      }
    } catch (_) {
      // fall through to MCP
    }

    try {
      final uri = 'agentforge://context/$owner/$repo/$prNumber';
      final result = await _jsonRpc(base, 'resources/read', {'uri': uri});
      final contents = result['contents'];
      if (contents is List && contents.isNotEmpty) {
        final first = contents.first;
        if (first is Map && first['text'] is String) {
          final text = first['text'] as String;
          final map = _tryDecodeMap(text) ?? {'plan': text};
          return AgentContext.fromJson(
            map,
            agentId: agent.id,
            agentName: agent.name,
            source: 'mcp',
          );
        }
      }
      if (result.isNotEmpty) {
        return AgentContext.fromJson(
          result,
          agentId: agent.id,
          agentName: agent.name,
          source: 'mcp',
        );
      }
    } catch (e) {
      return AgentContext.unavailable(
        agentId: agent.id,
        agentName: agent.name,
        error: _shortErr(e),
      );
    }

    return AgentContext.unavailable(
      agentId: agent.id,
      agentName: agent.name,
      error: 'No context endpoint responded',
    );
  }

  Future<FeedbackResult> sendFeedback({
    required AgentEntry agent,
    required String owner,
    required String repo,
    required int prNumber,
    required String message,
  }) async {
    final base = _root(agent.mcpBaseUrl);
    if (base.isEmpty) {
      return const FeedbackResult(ok: false, message: 'No MCP base URL');
    }
    if (message.trim().isEmpty) {
      return const FeedbackResult(ok: false, message: 'Empty feedback');
    }

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$base/feedback',
        data: {
          'owner': owner,
          'repo': repo,
          'pr': prNumber,
          'message': message.trim(),
        },
      );
      final data = res.data ?? const {};
      final ok = data['ok'] != false && (res.statusCode ?? 500) < 400;
      return FeedbackResult(
        ok: ok,
        message: (data['message'] ?? (ok ? 'Feedback sent' : 'Rejected'))
            as String,
      );
    } catch (_) {
      // MCP tools/call
    }

    try {
      final result = await _jsonRpc(base, 'tools/call', {
        'name': 'send_feedback',
        'arguments': {
          'owner': owner,
          'repo': repo,
          'pr': prNumber,
          'message': message.trim(),
        },
      });
      return FeedbackResult(
        ok: true,
        message: (result['message'] ?? result['content'] ?? 'Feedback sent')
            .toString(),
      );
    } catch (e) {
      return FeedbackResult(ok: false, message: _shortErr(e));
    }
  }

  Future<Map<String, dynamic>> _jsonRpc(
    String base,
    String method,
    Map<String, dynamic> params,
  ) async {
    final id = _rpcId++;
    final res = await _dio.post<Map<String, dynamic>>(
      '$base/mcp',
      data: {
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/event-stream',
        },
      ),
    );
    final data = res.data;
    if (data == null) throw StateError('Empty MCP response');
    if (data['error'] != null) {
      throw StateError(data['error'].toString());
    }
    final result = data['result'];
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return {'value': result};
  }

  Map<String, dynamic>? _tryDecodeMap(String text) {
    try {
      final v = text.trim();
      if (!v.startsWith('{')) return null;
      final decoded = jsonDecode(v);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _shortErr(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Agent unreachable (Tailscale / MCP URL?)';
      }
      return 'HTTP ${e.response?.statusCode ?? e.type.name}';
    }
    final s = e.toString();
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }
}
