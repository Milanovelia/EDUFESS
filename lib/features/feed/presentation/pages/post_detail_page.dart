import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(
        title: Text(
          'Post',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 16),
        ),
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(
                        post.displayAuthor.isNotEmpty ? post.displayAuthor[0].toUpperCase() : '?',
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.displayAuthor, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            '${_timeAgo(post.createdAt)} · ${PostType.labels[post.type] ?? post.type}${post.hasBestAnswer ? ' · Terjawab' : ''}',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'report') {
                          showReportDialog(context, ref, targetType: 'post', postId: post.id);
                        } else if (v == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hapus Post?'),
                              content: const Text('Post akan dihapus dan tidak bisa dikembalikan.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            final err = await ref.read(postInteractionProvider.notifier).deletePost(post.id);
                            if (context.mounted) {
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post berhasil dihapus.')));
                                context.pop();
                              }
                            }
                          }
                        } else if (v == 'edit') {
                          _showEditDialog(context, ref, post);
                        }
                      },
                      itemBuilder: (c) => [
                        if (post.isOwn) ...[
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                        const PopupMenuItem(value: 'report', child: Text('Laporkan')),
                      ],
                      icon: const Icon(Icons.more_vert, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(post.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: AppSpacing.xs),
                Text(post.content, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _DetailAction(
                      icon: post.currentUserHelpful ? Icons.favorite : Icons.favorite_border,
                      color: post.currentUserHelpful ? theme.colorScheme.secondary : null,
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
                    _DetailAction(
                      icon: Icons.chat_bubble_outline,
                      label: '${post.commentCount}',
                      tooltip: 'Komentar',
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _DetailAction(
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
                const Divider(height: AppSpacing.lg),
                const SizedBox(height: AppSpacing.lg),
                Text('Komentar', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.md),
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
                            canMarkBest: post.isOwn && post.type == PostType.question,
                            onMarkBest: post.isOwn && post.type == PostType.question
                                ? () async {
                                    final err = await ref.read(postInteractionProvider.notifier).markBestAnswer(
                                          commentId: c.id,
                                          postId: post.id,
                                          isBest: !c.isBestAnswer,
                                        );
                                    if (err != null && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                    }
                                  }
                                : null,
                            onReply: () => setState(() {
                              _replyToId = c.id;
                              _replyToName = c.displayAuthor;
                            }),
                            onDelete: c.isOwn
                                ? () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Hapus komentar?'),
                                        content: const Text('Komentar akan dihapus.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && context.mounted) {
                                      final err = await ref.read(postInteractionProvider.notifier).deleteComment(commentId: c.id, postId: post.id);
                                      if (err != null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                      }
                                    }
                                  }
                                : null,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Post post) {
    final titleCtrl = TextEditingController(text: post.title);
    final contentCtrl = TextEditingController(text: post.content);
    String selectedType = post.type;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlgState) => AlertDialog(
          title: const Text('Edit Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Judul', border: OutlineInputBorder()),
                  maxLength: 200,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(labelText: 'Konten', border: OutlineInputBorder()),
                  maxLines: 6,
                  maxLength: 10000,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: PostType.all.map((t) => ChoiceChip(
                    label: Text(PostType.labels[t]!),
                    selected: selectedType == t,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setDlgState(() => selectedType = t),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final err = await ref.read(postInteractionProvider.notifier).editPost(
                      postId: post.id,
                      title: titleCtrl.text.trim(),
                      content: contentCtrl.text.trim(),
                      type: selectedType,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'Post berhasil diperbarui.')),
                  );
                  if (err == null) ref.invalidate(postDetailProvider(post.id));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
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

class _DetailAction extends StatelessWidget {
  const _DetailAction({required this.icon, required this.label, this.tooltip, this.color, this.onTap});
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
    if (onTap == null) {
      final tip = tooltip;
      if (tip == null || tip.isEmpty) return child;
      return Tooltip(message: tip, child: child);
    }
    final tappable = InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: child));
    final tip = tooltip;
    if (tip == null || tip.isEmpty) return tappable;
    return Tooltip(message: tip, child: tappable);
  }
}
