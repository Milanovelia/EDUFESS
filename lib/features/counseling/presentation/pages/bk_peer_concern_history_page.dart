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
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  title: Text(concern.targetDisplay),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(concern.reasonLabel, style: Theme.of(context).textTheme.labelSmall),
                      Text(concern.statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      Text('${concern.createdAt.day}/${concern.createdAt.month}/${concern.createdAt.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
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
