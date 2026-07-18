/// Live context from a local coding agent (MCP / AgentForge HTTP contract).
class AgentContext {
  const AgentContext({
    required this.agentId,
    required this.agentName,
    this.plan = '',
    this.rationaleSummary = '',
    this.recentActions = const [],
    this.status = '',
    this.updatedAt,
    this.rawSource = 'http',
    this.sourceEndpoint = '',
    this.error,
  });

  final String agentId;
  final String agentName;
  final String plan;
  final String rationaleSummary;
  final List<String> recentActions;
  final String status;
  final DateTime? updatedAt;
  final String rawSource;

  /// Normalized side-car endpoint that produced this context.
  final String sourceEndpoint;
  final String? error;

  bool get hasContent =>
      plan.trim().isNotEmpty ||
      rationaleSummary.trim().isNotEmpty ||
      recentActions.isNotEmpty;

  factory AgentContext.fromJson(
    Map<String, dynamic> json, {
    required String agentId,
    required String agentName,
    String source = 'http',
    String sourceEndpoint = '',
  }) {
    final actions = <String>[];
    final rawActions =
        json['recent_actions'] ?? json['recentActions'] ?? json['actions'];
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
    final updated =
        json['updated_at'] as String? ?? json['updatedAt'] as String?;
    return AgentContext(
      agentId: agentId,
      agentName: agentName,
      plan: (json['plan'] ?? '') as String,
      // Legacy `reasoning` remains readable, but new side-cars should expose an
      // authored rationale summary rather than private chain-of-thought.
      rationaleSummary:
          (json['rationale_summary'] ?? json['reasoning'] ?? '') as String,
      recentActions: actions,
      status: (json['status'] ?? '') as String,
      updatedAt: updated != null ? DateTime.tryParse(updated) : null,
      rawSource: source,
      sourceEndpoint: sourceEndpoint,
    );
  }

  factory AgentContext.unavailable({
    required String agentId,
    required String agentName,
    required String error,
    String sourceEndpoint = '',
  }) {
    return AgentContext(
      agentId: agentId,
      agentName: agentName,
      sourceEndpoint: sourceEndpoint,
      error: error,
    );
  }
}

class FeedbackResult {
  const FeedbackResult({
    required this.ok,
    this.message = '',
    this.clientMessageId = '',
    this.deliveryId = '',
  });

  final bool ok;
  final String message;
  final String clientMessageId;
  final String deliveryId;
}
