import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/agents/agent_providers.dart';
import '../../core/forgejo/forgejo_client.dart';
import '../../core/forgejo/forgejo_providers.dart';
import '../../core/forgejo/models.dart';
import '../../core/mcp/mcp_providers.dart';
import '../../core/theme/widgets/error_state.dart';
import 'agent_context_panel.dart';

class PrDetailScreen extends ConsumerStatefulWidget {
  final String owner;
  final String repo;
  final int number;

  const PrDetailScreen({
    super.key,
    required this.owner,
    required this.repo,
    required this.number,
  });

  @override
  ConsumerState<PrDetailScreen> createState() => _PrDetailScreenState();
}

class _PrDetailScreenState extends ConsumerState<PrDetailScreen> {
  final _commentController = TextEditingController();
  var _busy = false;

  PrKey get _key => PrKey(widget.owner, widget.repo, widget.number);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      if (success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(forgejoErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _postComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;
    await _run(() async {
      await ref.read(prActionsProvider).postComment(_key, body);
      _commentController.clear();
    }, success: 'Comment posted');
  }

  Future<void> _review(ReviewEvent event, String label, String headSha) async {
    final body = _commentController.text.trim();
    if (event == ReviewEvent.requestChanges && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a review comment before requesting changes.'),
        ),
      );
      return;
    }
    if (headSha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refresh the PR before submitting a formal review.'),
        ),
      );
      return;
    }
    final shortSha = headSha.substring(0, headSha.length.clamp(0, 8));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text(
          'Target: ${widget.owner}/${widget.repo} #${widget.number} at '
          '$shortSha.\n\n'
          'AgentForge does not show diffs or checks yet. Verify them in '
          'Forgejo before submitting.\n\n'
          '${body.isEmpty ? 'Submit without an additional comment?' : 'Submit with the comment box as the review body?'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await ref
          .read(prActionsProvider)
          .submitReview(
            _key,
            event: event,
            expectedHeadSha: headSha,
            body: body,
          );
      _commentController.clear();
    }, success: '$label submitted');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detailAsync = ref.watch(pullRequestDetailProvider(_key));
    final commentsAsync = ref.watch(issueCommentsProvider(_key));
    final reviewsAsync = ref.watch(pullReviewsProvider(_key));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.owner}/${widget.repo} #${widget.number}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy
                ? null
                : () {
                    ref.invalidate(pullRequestDetailProvider(_key));
                    ref.invalidate(issueCommentsProvider(_key));
                    ref.invalidate(pullReviewsProvider(_key));
                    ref.invalidate(agentWorkMapProvider);
                    ref.invalidate(agentContextProvider(_key));
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          title: 'Could not load PR',
          message: forgejoErrorMessage(e),
          onRetry: () => ref.invalidate(pullRequestDetailProvider(_key)),
          fallback: '${widget.owner}/${widget.repo} #${widget.number}',
        ),
        data: (detail) {
          if (detail == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deep link target', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('${widget.owner}/${widget.repo} #${widget.number}'),
                  const SizedBox(height: 16),
                  Text(
                    'Connect Forgejo in Settings to load conversation and reviews.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          final s = detail.summary;
          final updated = s.updatedAt;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  children: [
                    if (s.draft)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            label: Text('Draft'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    Text(s.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      [
                        s.fullName,
                        '#${s.number}',
                        s.state,
                        if (s.user.login.isNotEmpty) 'by ${s.user.login}',
                        if (updated != null) timeago.format(updated),
                        if (detail.headSha.isNotEmpty)
                          'head ${detail.headSha.substring(0, detail.headSha.length.clamp(0, 8))}',
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Description', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SelectableText(
                      detail.body.trim().isEmpty
                          ? '(no description)'
                          : detail.body,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 28),
                    Text('Agent context', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    AgentContextPanel(prKey: _key),
                    const SizedBox(height: 28),
                    Text('Reviews', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    reviewsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => Text(forgejoErrorMessage(e)),
                      data: (reviews) {
                        if (reviews.isEmpty) {
                          return Text(
                            'No formal reviews yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final r in reviews) _ReviewTile(review: r),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text('Conversation', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                      error: (e, _) => Text(forgejoErrorMessage(e)),
                      data: (comments) {
                        if (comments.isEmpty) {
                          return Text(
                            'No comments yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final c in comments) _CommentTile(comment: c),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              _ReviewComposer(
                controller: _commentController,
                busy: _busy,
                onPostComment: _postComment,
                onApprove: () =>
                    _review(ReviewEvent.approve, 'Approve', detail.headSha),
                onRequestChanges: () => _review(
                  ReviewEvent.requestChanges,
                  'Request changes',
                  detail.headSha,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewComposer extends StatelessWidget {
  const _ReviewComposer({
    required this.controller,
    required this.busy,
    required this.onPostComment,
    required this.onApprove,
    required this.onRequestChanges,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onPostComment;
  final VoidCallback onApprove;
  final VoidCallback onRequestChanges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Review comment',
                  hintText: 'Comment or review body…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: busy ? null : onPostComment,
                    child: const Text('Comment'),
                  ),
                  FilledButton.tonal(
                    onPressed: busy ? null : onRequestChanges,
                    child: const Text('Request changes'),
                  ),
                  FilledButton(
                    onPressed: busy ? null : onApprove,
                    child: const Text('Approve'),
                  ),
                ],
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final IssueComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = comment.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (comment.user.login.isNotEmpty) comment.user.login,
                if (when != null) timeago.format(when),
              ].join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              comment.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final PullReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = review.submittedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (review.user.login.isNotEmpty) review.user.login,
                review.state,
                if (when != null) timeago.format(when),
              ].join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (review.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(
                review.body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
