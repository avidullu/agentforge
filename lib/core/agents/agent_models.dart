import 'dart:convert';

/// A registered local coding agent / machine (Milestone 3).
class AgentEntry {
  const AgentEntry({
    required this.id,
    required this.name,
    required this.machine,
    this.mcpBaseUrl = '',
    this.colorArgb = 0xFF10B981,
  });

  final String id;
  final String name;
  final String machine;
  final String mcpBaseUrl;
  final int colorArgb;

  AgentEntry copyWith({
    String? name,
    String? machine,
    String? mcpBaseUrl,
    int? colorArgb,
  }) {
    return AgentEntry(
      id: id,
      name: name ?? this.name,
      machine: machine ?? this.machine,
      mcpBaseUrl: mcpBaseUrl ?? this.mcpBaseUrl,
      colorArgb: colorArgb ?? this.colorArgb,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'machine': machine,
    'mcpBaseUrl': mcpBaseUrl,
    'colorArgb': colorArgb,
  };

  factory AgentEntry.fromJson(Map<String, dynamic> json) {
    return AgentEntry(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      machine: (json['machine'] ?? '') as String,
      mcpBaseUrl: (json['mcpBaseUrl'] ?? '') as String,
      colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFF10B981,
    );
  }

  static String encodeList(List<AgentEntry> agents) =>
      jsonEncode(agents.map((a) => a.toJson()).toList());

  static List<AgentEntry> decodeList(String? raw) {
    // Always return a growable list — callers mutate via add/remove.
    if (raw == null || raw.trim().isEmpty) return <AgentEntry>[];
    final data = jsonDecode(raw);
    if (data is! List) return <AgentEntry>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AgentEntry.fromJson)
        .where((a) => a.id.isNotEmpty && a.name.isNotEmpty)
        .toList();
  }
}

/// One piece of active work reported by an agent (MCP or stub).
class AgentWorkItem {
  const AgentWorkItem({
    required this.owner,
    required this.repo,
    required this.prNumber,
    this.branch = '',
    this.title = '',
    this.status = 'in_progress',
    this.updatedAt,
  });

  final String owner;
  final String repo;
  final int prNumber;
  final String branch;
  final String title;
  final String status;
  final DateTime? updatedAt;

  String get fullName => '$owner/$repo';

  bool isActiveAt(
    DateTime now, {
    Duration maxAge = const Duration(minutes: 5),
  }) {
    const activeStates = {'active', 'in_progress', 'working'};
    if (!activeStates.contains(status.toLowerCase()) || updatedAt == null) {
      return false;
    }
    final age = now.toUtc().difference(updatedAt!.toUtc());
    return age >= const Duration(minutes: -1) && age <= maxAge;
  }

  factory AgentWorkItem.fromJson(Map<String, dynamic> json) {
    final repo = (json['repo'] ?? '') as String;
    var owner = (json['owner'] ?? '') as String;
    var name = (json['name'] ?? '') as String;
    if (repo.split('/').length == 2) {
      final parts = repo.split('/');
      owner = parts.first;
      name = parts.last;
    }
    final updated =
        json['updated_at'] as String? ?? json['updatedAt'] as String?;
    return AgentWorkItem(
      owner: owner,
      repo: name,
      prNumber: switch (json['pr_number'] ?? json['prNumber']) {
        final int value => value,
        _ => 0,
      },
      branch: (json['branch'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      status: (json['status'] ?? '') as String,
      updatedAt: updated == null ? null : DateTime.tryParse(updated),
    );
  }
}

/// Per-endpoint activity result.
///
/// An empty successful result means the endpoint reported no fresh work. It is
/// deliberately distinct from an unconfigured or unreachable endpoint so the
/// UI never presents transport failure as an idle signal.
class AgentWorkResult {
  const AgentWorkResult._({
    required this.items,
    required this.endpointConfigured,
    required this.sourceEndpoint,
    this.error,
  });

  const AgentWorkResult.available(
    List<AgentWorkItem> items, {
    required String sourceEndpoint,
  }) : this._(
         items: items,
         endpointConfigured: true,
         sourceEndpoint: sourceEndpoint,
       );

  const AgentWorkResult.notConfigured()
    : this._(items: const [], endpointConfigured: false, sourceEndpoint: '');

  const AgentWorkResult.unavailable(String error, {String sourceEndpoint = ''})
    : this._(
        items: const [],
        endpointConfigured: true,
        sourceEndpoint: sourceEndpoint,
        error: error,
      );

  final List<AgentWorkItem> items;
  final bool endpointConfigured;

  /// Normalized endpoint that produced this result. Used to prevent retained
  /// async state from being joined to an edited agent that reused the same ID.
  final String sourceEndpoint;
  final String? error;

  bool get isUnavailable => error != null;
}
