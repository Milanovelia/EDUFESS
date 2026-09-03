import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../feed/data/models/post.dart';
import '../../../../app/router.dart';
import '../providers/feed_providers.dart';

/// Reusable small card for feed/explore.
class PostCard extends ConsumerWidget {
  const PostCard({required this.post, super.key});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => context.push('${AppRoutes.postDetailBase}/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(PostType.labels[post.type] ?? post.type, style: theme.textTheme.labelSmall),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Chip(
                    label: Text(post.subjectName, style: theme.textTheme.labelSmall),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (post.topicName != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Chip(
                      label: Text(post.topicName!, style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                  if (post.hasBestAnswer) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Chip(
                      label: Text('Terjawab', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white)),
                      backgroundColor: Colors.green,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(post.displayAuthor, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: AppSpacing.xs),
              Text(post.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Text(post.preview, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(_timeAgo(post.createdAt), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                  const Spacer(),
                  _ActionIcon(
                    icon: post.currentUserHelpful ? Icons.favorite : Icons.favorite_border,
                    color: post.currentUserHelpful ? Colors.red : null,
                    label: '${post.helpfulCount}',
                    onTap: () async {
                      final err = await ref.read(postInteractionProvider.notifier).toggleHelpful(post);
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ActionIcon(icon: Icons.chat_bubble_outline, label: '${post.commentCount}'),
                  const SizedBox(width: AppSpacing.sm),
                  _ActionIcon(
                    icon: post.currentUserBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: post.currentUserBookmarked ? theme.colorScheme.primary : null,
                    label: post.currentUserBookmarked ? 'Tersimpan' : 'Simpan',
                    onTap: () async {
                      final err = await ref.read(postInteractionProvider.notifier).toggleBookmark(post);
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(post.currentUserBookmarked ? 'Bookmark dihapus.' : 'Postingan disimpan.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
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

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.label, this.color, this.onTap});
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]);
    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: child));
  }
}
