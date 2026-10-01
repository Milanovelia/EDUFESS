import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/peer_concern_providers.dart';

class BkPeerConcernHistoryPage extends ConsumerWidget {
  const BkPeerConcernHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(studentPeerConcernsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Peduli Teman')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: ${e.toString().replaceAll('PeerConcernException: ', '')}')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Belum ada kepedulian yang kamu sampaikan.'));
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final concern = list[i];
              final closed = concern.closedAt ?? concern.handledAt;
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(concern.targetDisplay, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600))),
                          if (concern.status == 'pending')
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'withdraw') {
                                  _confirmWithdraw(context, ref, concern.id);
                                }
                              },
                              itemBuilder: (c) => const [
                                PopupMenuItem(value: 'withdraw', child: Text('Tarik Laporan')),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(concern.reasonLabel, style: Theme.of(context).textTheme.labelSmall),
                      Text(concern.statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      Text('Dikirim: ${concern.createdAt.day}/${concern.createdAt.month}/${concern.createdAt.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                      if (closed != null) Text('Ditutup: ${closed.day}/${closed.month}/${closed.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                      if (concern.status == 'withdrawn' && concern.withdrawnAt != null)
                        Text('Ditarik pada: ${concern.withdrawnAt!.day}/${concern.withdrawnAt!.month}/${concern.withdrawnAt!.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                      // resolution_note is never exposed here by design;
                      // only the counselor's student-visible response shows.
                      if (concern.reporterResponse != null && concern.reporterResponse!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text('Tanggapan Guru BK', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text(concern.reporterResponse!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Confirms and performs reporter withdrawal of a still-pending concern.
Future<void> _confirmWithdraw(BuildContext context, WidgetRef ref, String concernId) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tarik laporan?'),
      content: const Text('Laporan yang ditarik tidak akan diproses oleh guru BK. Riwayat laporan tetap tersimpan dan tidak dapat dikembalikan ke status menunggu.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tarik Laporan')),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return;
  final err = await ref.read(peerConcernControllerProvider.notifier).withdraw(concernId);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Laporan berhasil ditarik.')));
}
