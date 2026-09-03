import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/feed_providers.dart';
import '../../data/models/post.dart';
import '../../../moderation/presentation/widgets/report_dialog.dart';

/// `/post/:id` — displays full post content.
class PostDetailPage extends ConsumerWidget {
  const PostDetailPage({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postDetailProvider(postId));
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
                  onPressed: () => ref.invalidate(postDetailProvider(postId)),
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
                    Chip(label: Text(post.subjectName)),
                    if (post.topicName != null) Chip(label: Text(post.topicName!)),
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
