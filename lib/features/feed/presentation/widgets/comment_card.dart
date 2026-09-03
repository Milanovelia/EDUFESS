import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/models/comment.dart';
import '../../../moderation/presentation/widgets/report_dialog.dart';

/// Single comment/best-answer card.
class CommentCard extends ConsumerWidget {
  const CommentCard({
    required this.comment,
    this.onReply,
    this.onMarkBest,
    this.canMarkBest = false,
    this.onDelete,
    super.key,
  });

  final Comment comment;
  final VoidCallback? onReply;
  final VoidCallback? onMarkBest;
  final bool canMarkBest;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(
        left: comment.isReply ? AppSpacing.lg : 0,
        bottom: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: comment.isBestAnswer ? Colors.green.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: comment.isBestAnswer ? Border.all(color: Colors.green) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(comment.displayAuthor, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(width: AppSpacing.sm),
              Text(_timeAgo(comment.createdAt), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              const Spacer(),
              if (comment.isBestAnswer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                  child: const Text('Jawaban Terbaik', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(comment.content, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (!comment.isReply && onReply != null)
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Balas'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              if (canMarkBest && !comment.isBestAnswer)
                TextButton.icon(
                  onPressed: onMarkBest,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Tandai Terbaik'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              if (canMarkBest && comment.isBestAnswer)
                TextButton.icon(
                  onPressed: onMarkBest,
                  icon: const Icon(Icons.remove_circle_outline, size: 16),
                  label: const Text('Batalkan'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              if (comment.isOwn && onDelete != null)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Hapus'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'report') showReportDialog(context, ref, targetType: 'comment', commentId: comment.id);
                },
                itemBuilder: (c) => const [PopupMenuItem(value: 'report', child: Text('Laporkan'))],
                icon: const Icon(Icons.more_vert, size: 16),
              ),
            ],
          ),
        ],
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
