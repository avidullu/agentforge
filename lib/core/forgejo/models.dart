/// Minimal Forgejo user as returned on issues/PRs.
class ForgejoUser {
  const ForgejoUser({required this.login, this.fullName = ''});

  final String login;
  final String fullName;

  factory ForgejoUser.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ForgejoUser(login: '');
    return ForgejoUser(
      login: (json['login'] ?? json['username'] ?? '') as String,
      fullName: (json['full_name'] ?? '') as String,
    );
  }
}

/// Open pull request summary for list UIs.
class PullRequestSummary {
  const PullRequestSummary({
    required this.owner,
    required this.repo,
    required this.number,
    required this.title,
    required this.state,
    required this.htmlUrl,
    required this.updatedAt,
    required this.user,
    this.draft = false,
  });

  final String owner;
  final String repo;
  final int number;
  final String title;
  final String state;
  final String htmlUrl;
  final DateTime? updatedAt;
  final ForgejoUser user;
  final bool draft;

  String get fullName => '$owner/$repo';

  /// go_router location for PR detail.
  String get routePath => '/$owner/$repo/pulls/$number';

  /// Parse from `/api/v1/repos/{owner}/{repo}/pulls/{n}` items.
  factory PullRequestSummary.fromPullJson(
    Map<String, dynamic> json, {
    required String owner,
    required String repo,
  }) {
    final updated = json['updated_at'] as String?;
    return PullRequestSummary(
      owner: owner,
      repo: repo,
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '') as String,
      state: (json['state'] ?? 'open') as String,
      htmlUrl: (json['html_url'] ?? '') as String,
      updatedAt: updated != null ? DateTime.tryParse(updated) : null,
      user: ForgejoUser.fromJson(json['user'] as Map<String, dynamic>?),
      draft: json['draft'] == true,
    );
  }

  /// Parse from `/api/v1/repos/issues/search?type=pulls` items.
  factory PullRequestSummary.fromIssueSearchJson(Map<String, dynamic> json) {
    final repo = json['repository'] as Map<String, dynamic>? ?? {};
    final owner = (repo['owner'] ?? '') as String;
    final name = (repo['name'] ?? '') as String;
    final pr = json['pull_request'] as Map<String, dynamic>? ?? {};
    final updated = json['updated_at'] as String?;

    return PullRequestSummary(
      owner: owner,
      repo: name,
      number: (json['number'] as num?)?.toInt() ?? 0,
      title: (json['title'] ?? '') as String,
      state: (json['state'] ?? 'open') as String,
      htmlUrl: (json['html_url'] ?? pr['html_url'] ?? '') as String,
      updatedAt: updated != null ? DateTime.tryParse(updated) : null,
      user: ForgejoUser.fromJson(json['user'] as Map<String, dynamic>?),
      draft: pr['draft'] == true,
    );
  }
}

/// PR detail including body (Milestone 1 read-only; reviews in M2).
class PullRequestDetail {
  const PullRequestDetail({
    required this.summary,
    required this.body,
  });

  final PullRequestSummary summary;
  final String body;

  factory PullRequestDetail.fromPullJson(
    Map<String, dynamic> json, {
    required String owner,
    required String repo,
  }) {
    return PullRequestDetail(
      summary: PullRequestSummary.fromPullJson(
        json,
        owner: owner,
        repo: repo,
      ),
      body: (json['body'] ?? '') as String,
    );
  }
}
