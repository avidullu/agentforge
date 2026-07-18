import 'package:dio/dio.dart';

import '../mcp/mcp_client.dart';
import 'agent_models.dart';

/// Fetches active work while preserving endpoint health separately from idle.
///
/// Tries `GET {mcpBaseUrl}/active-work` returning a JSON array (or
/// `{ "items": [...] }`). Transport and payload failures become typed
/// unavailable results; they are never collapsed into an empty activity list.
class AgentWorkClient {
  AgentWorkClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
            ),
          ) {
    _dio.options
      ..followRedirects = false
      ..maxRedirects = 0;
  }

  final Dio _dio;

  Future<AgentWorkResult> fetchActiveWork(AgentEntry agent) async {
    final rawBase = agent.mcpBaseUrl.trim();
    if (rawBase.isEmpty) return const AgentWorkResult.notConfigured();
    late final String base;
    try {
      base = normalizeAgentEndpointUrl(rawBase);
    } on FormatException catch (error) {
      return AgentWorkResult.unavailable(error.message);
    }
    final url = base.endsWith('/') ? '${base}active-work' : '$base/active-work';
    try {
      final res = await _dio.get<dynamic>(url);
      final data = res.data;
      final list = _asList(data);
      if (list == null) {
        return AgentWorkResult.unavailable(
          'Unexpected active-work response',
          sourceEndpoint: base,
        );
      }
      if (list.any((item) => item is! Map<String, dynamic>)) {
        return AgentWorkResult.unavailable(
          'Invalid active-work item',
          sourceEndpoint: base,
        );
      }
      final maps = list.cast<Map<String, dynamic>>();
      if (maps.any((item) => !_hasRequiredActivityFields(item))) {
        return AgentWorkResult.unavailable(
          'Invalid active-work item',
          sourceEndpoint: base,
        );
      }
      final parsed = maps.map(AgentWorkItem.fromJson).toList();
      if (parsed.any(
        (work) => work.owner.isEmpty || work.repo.isEmpty || work.prNumber <= 0,
      )) {
        return AgentWorkResult.unavailable(
          'Invalid active-work item',
          sourceEndpoint: base,
        );
      }
      final items = parsed
          .where((w) => w.isActiveAt(DateTime.now().toUtc()))
          .toList();
      return AgentWorkResult.available(items, sourceEndpoint: base);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      return AgentWorkResult.unavailable(
        status == null
            ? 'Endpoint activity unavailable'
            : 'Endpoint activity failed (HTTP $status)',
        sourceEndpoint: base,
      );
    } catch (_) {
      return AgentWorkResult.unavailable(
        'Invalid active-work response',
        sourceEndpoint: base,
      );
    }
  }

  List<dynamic>? _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['items'] is List) {
      return data['items'] as List<dynamic>;
    }
    if (data is Map && data['work'] is List) {
      return data['work'] as List<dynamic>;
    }
    return null;
  }

  bool _hasRequiredActivityFields(Map<String, dynamic> item) {
    final repo = item['repo'];
    final repoParts = repo is String ? repo.split('/') : const <String>[];
    final prNumber = item['pr_number'] ?? item['prNumber'];
    final status = item['status'];
    final updated = item['updated_at'] ?? item['updatedAt'];
    return repoParts.length == 2 &&
        repoParts.every((part) => part.trim().isNotEmpty) &&
        prNumber is int &&
        prNumber > 0 &&
        status is String &&
        status.trim().isNotEmpty &&
        updated is String &&
        DateTime.tryParse(updated) != null;
  }
}
