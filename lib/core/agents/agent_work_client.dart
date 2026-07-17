import 'package:dio/dio.dart';

import 'agent_models.dart';

/// Best-effort fetch of an agent's active work.
///
/// Tries `GET {mcpBaseUrl}/active-work` returning a JSON array (or
/// `{ "items": [...] }`). Soft-fails to empty list when unreachable —
/// full MCP Streamable HTTP lands in Milestone 4.
class AgentWorkClient {
  AgentWorkClient({Dio? dio}) : _dio = dio ?? Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 8),
          ),
        );

  final Dio _dio;

  Future<List<AgentWorkItem>> fetchActiveWork(AgentEntry agent) async {
    final base = agent.mcpBaseUrl.trim();
    if (base.isEmpty) return const [];
    final url = base.endsWith('/')
        ? '${base}active-work'
        : '$base/active-work';
    try {
      final res = await _dio.get<dynamic>(url);
      final data = res.data;
      final list = _asList(data);
      return list
          .whereType<Map<String, dynamic>>()
          .map(AgentWorkItem.fromJson)
          .where((w) => w.owner.isNotEmpty && w.repo.isNotEmpty && w.prNumber > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['items'] is List) {
      return data['items'] as List<dynamic>;
    }
    if (data is Map && data['work'] is List) {
      return data['work'] as List<dynamic>;
    }
    return const [];
  }
}
