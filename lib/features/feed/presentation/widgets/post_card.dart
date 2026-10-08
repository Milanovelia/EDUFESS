import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../feed/data/models/post.dart';
import '../../../../app/router.dart';
import '../providers/feed_providers.dart';
import '../../../moderation/presentation/widgets/report_dialog.dart';

/// Lightweight social post row for feed/explore.
class PostCard extends ConsumerWidget {
  const PostCard({required this.post, super.key});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => context.push('${AppRoutes.postDetailBase}/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      post.displayAuthor.isNotEmpty ? post.displayAuthor[0].toUpperCase() : '?',
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: post.displayAuthor, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                                    TextSpan(text: ' · ${_timeAgo(post.createdAt)}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'report') showReportDialog(context, ref, targetType: 'post', postId: post.id);
                              },
                              itemBuilder: (c) => const [PopupMenuItem(value: 'report', child: Text('Laporkan'))],
                              icon: const Icon(Icons.more_vert, size: 18),
                            ),
                          ],
                        ),
                        Text(post.title, style: theme.textTheme.titleSmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(post.preview, style: theme.textTheme.bodyMedium, maxLines: 5, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            if (post.hasBestAnswer)
                              Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.sm),
                                child: Text('Terjawab', style: theme.textTheme.labelSmall?.copyWith(color: Colors.green, fontWeight: FontWeight.w600)),
                              ),
                            _ActionIcon(
                              icon: post.currentUserHelpful ? Icons.favorite : Icons.favorite_border,
                              color: post.currentUserHelpful ? Colors.red : null,
                              label: '${post.helpfulCount}',
                              tooltip: 'Suka',
                              onTap: () async {
                                final err = await ref.read(postInteractionProvider.notifier).toggleHelpful(post);
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                }
                              },
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _ActionIcon(
                              icon: Icons.chat_bubble_outline,
                              label: '${post.commentCount}',
                              tooltip: 'Komentar',
                              onTap: () => context.push('${AppRoutes.postDetailBase}/${post.id}'),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            _ActionIcon(
                              icon: post.currentUserBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              color: post.currentUserBookmarked ? theme.colorScheme.primary : null,
                              label: '',
                              tooltip: post.currentUserBookmarked ? 'Hapus bookmark' : 'Bookmark',
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
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Divider(height: 1),
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
  const _ActionIcon({required this.icon, required this.label, this.tooltip, this.color, this.onTap});
  final IconData icon;
  final String label;
  final String? tooltip;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 18, color: color),
      if (label.isNotEmpty) ...[
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ]);
    if (onTap == null) return child;
    final tappable = InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: child));
    final tip = tooltip;
    if (tip == null || tip.isEmpty) return tappable;
    return Tooltip(message: tip, child: tappable);
  }
}
