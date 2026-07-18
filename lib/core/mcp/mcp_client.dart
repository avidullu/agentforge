import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../agents/agent_models.dart';
import 'mcp_models.dart';

/// Validates and normalizes a configured agent side-car base URL.
///
/// Remote control traffic must use HTTPS. Plain HTTP is accepted only for a
/// loopback-only development server on the same device.
String normalizeAgentEndpointUrl(String base) {
  final uri = Uri.tryParse(base.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const FormatException('Agent endpoint must be an absolute URL');
  }
  if (uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw const FormatException(
      'Agent endpoint cannot contain credentials, query, or fragment',
    );
  }
  final host = uri.host.toLowerCase();
  final isLoopback = host == 'localhost' || host == '127.0.0.1';
  if (uri.scheme != 'https' && !(uri.scheme == 'http' && isLoopback)) {
    throw const FormatException(
      'Agent endpoint must use HTTPS (HTTP is allowed only on loopback)',
    );
  }
  var normalized = uri.toString();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

/// Thin client for AgentForge agent side-cars.
///
/// **Preferred HTTP contract** (easy for wrappers):
/// - `GET  {base}/active-work`
/// - `GET  {base}/context?owner=&repo=&pr=`
/// - `POST {base}/feedback`  body: `{owner,repo,pr,message}`
///
/// **Experimental JSON-RPC compatibility adapter** at `{base}/mcp`:
/// - `resources/read` uri `agentforge://context/{owner}/{repo}/{pr}`
///
/// This is not a complete MCP Streamable HTTP session client. Mutating
/// feedback uses only the idempotent side-car endpoint until MCP lifecycle,
/// capability negotiation, authentication, and SSE are implemented.
class McpClient {
  McpClient({Dio? dio, Uuid? uuid})
    : _uuid = uuid ?? const Uuid(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 12),
              headers: {'Accept': 'application/json'},
            ),
          ) {
    _dio.options
      ..followRedirects = false
      ..maxRedirects = 0;
  }

  final Dio _dio;
  final Uuid _uuid;
  int _rpcId = 1;

  String _root(String base) => normalizeAgentEndpointUrl(base);

  Future<AgentContext> fetchContext({
    required AgentEntry agent,
    required String owner,
    required String repo,
    required int prNumber,
  }) async {
    late final String base;
    try {
      base = _root(agent.mcpBaseUrl);
    } catch (e) {
      return AgentContext.unavailable(
        agentId: agent.id,
        agentName: agent.name,
        error: _shortErr(e),
      );
    }
    if (base.isEmpty) {
      return AgentContext.unavailable(
        agentId: agent.id,
        agentName: agent.name,
        error: 'No agent side-car URL configured',
        sourceEndpoint: base,
      );
    }

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$base/context',
        queryParameters: {'owner': owner, 'repo': repo, 'pr': prNumber},
      );
      if (res.data != null) {
        return AgentContext.fromJson(
          res.data!,
          agentId: agent.id,
          agentName: agent.name,
          sourceEndpoint: base,
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
            sourceEndpoint: base,
          );
        }
      }
      if (result.isNotEmpty) {
        return AgentContext.fromJson(
          result,
          agentId: agent.id,
          agentName: agent.name,
          source: 'mcp',
          sourceEndpoint: base,
        );
      }
    } catch (e) {
      return AgentContext.unavailable(
        agentId: agent.id,
        agentName: agent.name,
        error: _shortErr(e),
        sourceEndpoint: base,
      );
    }

    return AgentContext.unavailable(
      agentId: agent.id,
      agentName: agent.name,
      error: 'No context endpoint responded',
      sourceEndpoint: base,
    );
  }

  Future<FeedbackResult> sendFeedback({
    required AgentEntry agent,
    required String owner,
    required String repo,
    required int prNumber,
    required String message,
    String clientMessageId = '',
  }) async {
    late final String base;
    try {
      base = _root(agent.mcpBaseUrl);
    } catch (e) {
      return FeedbackResult(ok: false, message: _shortErr(e));
    }
    if (message.trim().isEmpty) {
      return const FeedbackResult(ok: false, message: 'Empty feedback');
    }

    final messageId = clientMessageId.trim().isEmpty
        ? _uuid.v4()
        : clientMessageId.trim();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$base/feedback',
        data: {
          'owner': owner,
          'repo': repo,
          'pr': prNumber,
          'message': message.trim(),
          'client_message_id': messageId,
          'idempotency_key': messageId,
        },
      );
      final data = res.data ?? const {};
      final rawDeliveryId = data['delivery_id'];
      final deliveryId = rawDeliveryId is String ? rawDeliveryId.trim() : '';
      final accepted = data['ok'] == true && (res.statusCode ?? 500) < 400;
      final ok = accepted && deliveryId.isNotEmpty;
      return FeedbackResult(
        ok: ok,
        message: accepted && deliveryId.isEmpty
            ? 'Side-car accepted feedback without a delivery receipt. '
                  'Retry the unchanged draft with its existing message ID.'
            : (data['message'] ?? (ok ? 'Feedback queued' : 'Rejected'))
                  .toString(),
        clientMessageId: messageId,
        deliveryId: deliveryId,
      );
    } catch (e) {
      // Never retry an ambiguous write through another transport: the REST
      // endpoint may have accepted it before a timeout or malformed response.
      return FeedbackResult(
        ok: false,
        message: _shortErr(e),
        clientMessageId: messageId,
      );
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
      data: {'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          // This compatibility adapter only accepts JSON responses.
          'Accept': 'application/json',
        },
      ),
    );
    final data = res.data;
    if (data == null) throw StateError('Empty MCP response');
    if (data['id'] != id) throw StateError('MCP response id mismatch');
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
