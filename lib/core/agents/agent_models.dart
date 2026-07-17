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
    if (raw == null || raw.trim().isEmpty) return const [];
    final data = jsonDecode(raw);
    if (data is! List) return const [];
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
  });

  final String owner;
  final String repo;
  final int prNumber;
  final String branch;
  final String title;
  final String status;

  String get fullName => '$owner/$repo';

  factory AgentWorkItem.fromJson(Map<String, dynamic> json) {
    final repo = (json['repo'] ?? '') as String;
    var owner = (json['owner'] ?? '') as String;
    var name = (json['name'] ?? '') as String;
    if (repo.contains('/')) {
      final parts = repo.split('/');
      owner = parts.first;
      name = parts.sublist(1).join('/');
    }
    return AgentWorkItem(
      owner: owner,
      repo: name,
      prNumber: (json['pr_number'] as num?)?.toInt() ??
          (json['prNumber'] as num?)?.toInt() ??
          0,
      branch: (json['branch'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      status: (json['status'] ?? 'in_progress') as String,
    );
  }
}
