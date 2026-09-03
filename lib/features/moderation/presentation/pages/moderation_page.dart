import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/moderation_providers.dart';
import '../../data/models/moderation_report.dart';

/// Admin moderation queue — shows pending reports.
class ModerationPage extends ConsumerWidget {
  const ModerationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final queueAsync = ref.watch(moderationQueueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Moderasi')),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat antrean moderasi.')),
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(child: Text('Tidak memiliki akses moderasi.'));
          }
          return queueAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text(e.toString().contains('ReportException') ? e.toString().replaceAll('ReportException: ', '') : 'Gagal memuat antrean moderasi.', textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: () => ref.invalidate(moderationQueueProvider), child: const Text('Coba lagi')),
                  ],
                ),
              ),
            ),
            data: (reports) {
              if (reports.isEmpty) {
                return const Center(child: Text('Tidak ada laporan pending.'));
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(moderationQueueProvider),
                child: ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, i) => _ReportCard(report: reports[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final ModerationReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(report.isPost ? 'Post' : 'Komentar')),
                const SizedBox(width: AppSpacing.sm),
                Chip(label: Text(ReportReason.labels[report.reason] ?? report.reason)),
                const Spacer(),
                Text(_timeAgo(report.createdAt), style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(report.displayAuthor, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
            if (report.targetTitle != null) ...[
              const SizedBox(height: 4),
              Text(report.targetTitle!, style: theme.textTheme.titleSmall),
            ],
            const SizedBox(height: 4),
            Text(report.targetContent ?? '', style: theme.textTheme.bodySmall, maxLines: 4, overflow: TextOverflow.ellipsis),
            if (report.details != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Detail: ${report.details}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Tolak laporan?'),
                        content: const Text('Laporan akan ditandai selesai tanpa menghapus konten.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tolak')),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    final err = await ref.read(moderationActionProvider.notifier).dismiss(report.reportId);
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan ditolak.')));
                      ref.invalidate(moderationQueueProvider);
                    }
                  },
                  child: const Text('Tolak'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hapus konten?'),
                        content: const Text('Konten akan dihapus (soft-delete) dan laporan diselesaikan.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    final err = await ref.read(moderationActionProvider.notifier).remove(report.reportId);
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konten dihapus.')));
                      ref.invalidate(moderationQueueProvider);
                    }
                  },
                  child: const Text('Hapus Konten'),
                ),
              ],
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
