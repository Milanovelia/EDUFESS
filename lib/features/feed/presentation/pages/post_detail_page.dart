import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/feed_providers.dart';
import '../widgets/comment_card.dart';
import '../widgets/comment_composer.dart';
import '../../data/models/post.dart';
import '../../../moderation/presentation/widgets/report_dialog.dart';

/// `/post/:id` — post with social discussion surface below content.
class PostDetailPage extends ConsumerStatefulWidget {
  const PostDetailPage({required this.postId, super.key});

  final String postId;

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  String? _replyToId;
  String? _replyToName;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(commentsProvider(widget.postId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Post')),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: AppSpacing.md),
                const Text('Gagal memuat post.', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(postDetailProvider(widget.postId)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (post) {
          if (post == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('Post tidak ditemukan atau telah dihapus.', textAlign: TextAlign.center),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    Chip(label: Text(PostType.labels[post.type] ?? post.type)),
                    if (post.hasBestAnswer)
                      const Chip(label: Text('Terjawab')),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: Text(post.displayAuthor, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary))),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'report') showReportDialog(context, ref, targetType: 'post', postId: post.id);
                      },
                      itemBuilder: (c) => const [PopupMenuItem(value: 'report', child: Text('Laporkan'))],
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(post.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(_timeAgo(post.createdAt), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                const Divider(height: AppSpacing.xl),
                Text(post.content, style: theme.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                Text('Komentar', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                commentsAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator())),
                  error: (e, _) => Center(
                    child: Column(
                      children: [
                        Text(e.toString().replaceAll('PostException: ', ''), textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: () => ref.invalidate(commentsProvider(widget.postId)),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                  data: (comments) {
                    if (comments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(child: Text('Belum ada komentar. Jadilah yang pertama!')),
                      );
                    }
                    return Column(
                      children: [
                        for (final c in comments)
                          CommentCard(
                            comment: c,
                            onReply: () => setState(() {
                              _replyToId = c.id;
                              _replyToName = c.displayAuthor;
                            }),
                            onDelete: c.isOwn
                                ? () async {
                                    final err = await ref.read(postInteractionProvider.notifier).deleteComment(commentId: c.id, postId: post.id);
                                    if (err != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                    }
                                  }
                                : null,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                CommentComposer(
                  replyToName: _replyToName,
                  onCancelReply: _replyToId == null
                      ? null
                      : () => setState(() {
                            _replyToId = null;
                            _replyToName = null;
                          }),
                  onSubmit: (content, isPseudonymous) async {
                    final err = await ref
                        .read(postInteractionProvider.notifier)
                        .createComment(
                          postId: post.id,
                          parentId: _replyToId,
                          content: content,
                          isPseudonymous: isPseudonymous,
                        );
                    if (err == null) {
                      setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      });
                    }
                    return err;
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
