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
                      Text(concern.targetDisplay, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(concern.reasonLabel, style: Theme.of(context).textTheme.labelSmall),
                      Text(concern.statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      Text('Dikirim: ${concern.createdAt.day}/${concern.createdAt.month}/${concern.createdAt.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                      if (closed != null) Text('Ditutup: ${closed.day}/${closed.month}/${closed.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
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
