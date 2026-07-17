import 'package:dio/dio.dart';

import '../settings/app_settings.dart';
import 'models.dart';

/// Thin Forgejo (Gitea-compatible) API client for the endpoints AgentForge needs.
class ForgejoClient {
  ForgejoClient({
    required AppSettings settings,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            ) {
    _dio.options.baseUrl = AppSettings.normalizeBaseUrl(settings.baseUrl);
    _dio.options.headers['Accept'] = 'application/json';
    final token = settings.token.trim();
    if (token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'token $token';
    }
  }

  final Dio _dio;

  /// Validates credentials; returns the authenticated login.
  Future<String> whoAmI() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/v1/user');
    final login = res.data?['login'] as String? ??
        res.data?['username'] as String? ??
        '';
    if (login.isEmpty) {
      throw ForgejoException('Unexpected /api/v1/user response');
    }
    return login;
  }

  /// Open pull requests visible to the token (across personal + org repos).
  Future<List<PullRequestSummary>> listOpenPullRequests({
    int limit = 50,
    int page = 1,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/repos/issues/search',
      queryParameters: {
        'type': 'pulls',
        'state': 'open',
        'limit': limit,
        'page': page,
      },
    );
    final data = res.data ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(PullRequestSummary.fromIssueSearchJson)
        .where((p) => p.owner.isNotEmpty && p.repo.isNotEmpty && p.number > 0)
        .toList();
  }

  /// Single PR by owner/repo/number.
  Future<PullRequestDetail> getPullRequest({
    required String owner,
    required String repo,
    required int number,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/v1/repos/$owner/$repo/pulls/$number',
    );
    final data = res.data;
    if (data == null) {
      throw ForgejoException('Empty PR response for $owner/$repo#$number');
    }
    return PullRequestDetail.fromPullJson(
      data,
      owner: owner,
      repo: repo,
    );
  }

  Future<List<IssueComment>> listIssueComments({
    required String owner,
    required String repo,
    required int number,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/repos/$owner/$repo/issues/$number/comments',
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(IssueComment.fromJson)
        .toList();
  }

  Future<IssueComment> createIssueComment({
    required String owner,
    required String repo,
    required int number,
    required String body,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/repos/$owner/$repo/issues/$number/comments',
      data: {'body': body},
    );
    final data = res.data;
    if (data == null) {
      throw ForgejoException('Empty comment response');
    }
    return IssueComment.fromJson(data);
  }

  Future<List<PullReview>> listPullReviews({
    required String owner,
    required String repo,
    required int number,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/v1/repos/$owner/$repo/pulls/$number/reviews',
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PullReview.fromJson)
        .toList();
  }

  /// Submit a formal review (approve / request changes / comment-only).
  Future<PullReview> createPullReview({
    required String owner,
    required String repo,
    required int number,
    required ReviewEvent event,
    String body = '',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/v1/repos/$owner/$repo/pulls/$number/reviews',
      data: {
        'body': body,
        'event': event.apiValue,
      },
    );
    final data = res.data;
    if (data == null) {
      throw ForgejoException('Empty review response');
    }
    return PullReview.fromJson(data);
  }
}

class ForgejoException implements Exception {
  ForgejoException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? message : '$message (HTTP $statusCode)';
}

/// Maps [DioException] into a short user-facing message.
String forgejoErrorMessage(Object error) {
  if (error is ForgejoException) return error.toString();
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Authentication failed ($code). Check your personal access token.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach Forgejo. Are you on Tailscale?';
    }
    final msg = error.response?.data;
    if (msg is Map && msg['message'] != null) {
      return '${msg['message']} (HTTP $code)';
    }
    return 'Forgejo request failed${code != null ? ' (HTTP $code)' : ''}.';
  }
  return error.toString();
}
