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
    required this.headSha,
    this.headRef = '',
    this.baseRef = '',
  });

  final PullRequestSummary summary;
  final String body;
  final String headSha;
  final String headRef;
  final String baseRef;

  factory PullRequestDetail.fromPullJson(
    Map<String, dynamic> json, {
    required String owner,
    required String repo,
  }) {
    final head =
        json['head'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final base =
        json['base'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return PullRequestDetail(
      summary: PullRequestSummary.fromPullJson(json, owner: owner, repo: repo),
      body: (json['body'] ?? '') as String,
      headSha: (head['sha'] ?? '') as String,
      headRef: (head['ref'] ?? '') as String,
      baseRef: (base['ref'] ?? '') as String,
    );
  }
}

/// Issue/PR conversation comment.
class IssueComment {
  const IssueComment({
    required this.id,
    required this.body,
    required this.user,
    required this.createdAt,
    this.htmlUrl = '',
  });

  final int id;
  final String body;
  final ForgejoUser user;
  final DateTime? createdAt;
  final String htmlUrl;

  factory IssueComment.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] as String?;
    return IssueComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      body: (json['body'] ?? '') as String,
      user: ForgejoUser.fromJson(json['user'] as Map<String, dynamic>?),
      createdAt: created != null ? DateTime.tryParse(created) : null,
      htmlUrl: (json['html_url'] ?? '') as String,
    );
  }
}

/// Formal PR review event.
enum ReviewEvent {
  comment('COMMENT'),
  approve('APPROVED'),
  requestChanges('REQUEST_CHANGES');

  const ReviewEvent(this.apiValue);
  final String apiValue;
}

class PullReview {
  const PullReview({
    required this.id,
    required this.state,
    required this.body,
    required this.user,
    this.submittedAt,
  });

  final int id;
  final String state;
  final String body;
  final ForgejoUser user;
  final DateTime? submittedAt;

  factory PullReview.fromJson(Map<String, dynamic> json) {
    final created =
        json['submitted_at'] as String? ?? json['created_at'] as String?;
    return PullReview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      state: (json['state'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      user: ForgejoUser.fromJson(json['user'] as Map<String, dynamic>?),
      submittedAt: created != null ? DateTime.tryParse(created) : null,
    );
  }
}
