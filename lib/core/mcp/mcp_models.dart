/// Live context from a local coding agent (MCP / AgentForge HTTP contract).
class AgentContext {
  const AgentContext({
    required this.agentId,
    required this.agentName,
    this.plan = '',
    this.reasoning = '',
    this.recentActions = const [],
    this.status = '',
    this.updatedAt,
    this.rawSource = 'http',
    this.error,
  });

  final String agentId;
  final String agentName;
  final String plan;
  final String reasoning;
  final List<String> recentActions;
  final String status;
  final DateTime? updatedAt;
  final String rawSource;
  final String? error;

  bool get hasContent =>
      plan.trim().isNotEmpty ||
      reasoning.trim().isNotEmpty ||
      recentActions.isNotEmpty;

  factory AgentContext.fromJson(
    Map<String, dynamic> json, {
    required String agentId,
    required String agentName,
    String source = 'http',
  }) {
    final actions = <String>[];
    final rawActions = json['recent_actions'] ?? json['recentActions'] ?? json['actions'];
    if (rawActions is List) {
      for (final a in rawActions) {
        if (a is String) {
          actions.add(a);
        } else if (a is Map && a['summary'] != null) {
          actions.add(a['summary'].toString());
        } else if (a is Map && a['text'] != null) {
          actions.add(a['text'].toString());
        }
      }
    }
    final updated = json['updated_at'] as String? ?? json['updatedAt'] as String?;
    return AgentContext(
      agentId: agentId,
      agentName: agentName,
      plan: (json['plan'] ?? '') as String,
      reasoning: (json['reasoning'] ?? json['thoughts'] ?? '') as String,
      recentActions: actions,
      status: (json['status'] ?? '') as String,
      updatedAt: updated != null ? DateTime.tryParse(updated) : null,
      rawSource: source,
    );
  }

  factory AgentContext.unavailable({
    required String agentId,
    required String agentName,
    required String error,
  }) {
    return AgentContext(
      agentId: agentId,
      agentName: agentName,
      error: error,
    );
  }
}

class FeedbackResult {
  const FeedbackResult({required this.ok, this.message = ''});

  final bool ok;
  final String message;
}
