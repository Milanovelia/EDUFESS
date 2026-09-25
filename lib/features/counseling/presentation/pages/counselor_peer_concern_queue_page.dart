import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../app/router.dart';
import '../providers/peer_concern_providers.dart';

class CounselorPeerConcernQueuePage extends ConsumerWidget {
  const CounselorPeerConcernQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(counselorPeerConcernQueueProvider);
    final historyAsync = ref.watch(counselorPeerConcernHistoryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Peduli Teman'),
          bottom: const TabBar(tabs: [Tab(text: 'Menunggu'), Tab(text: 'Sedang Ditangani'), Tab(text: 'Riwayat')]),
        ),
        body: TabBarView(
          children: [
            // Menunggu
            queueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: ${e.toString().replaceAll('PeerConcernException: ', '')}')),
              data: (list) {
                if (list.isEmpty) return const Center(child: Text('Tidak ada laporan yang menunggu.'));
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(counselorPeerConcernQueueProvider),
                  child: ListView.builder(
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
                              Text('${concern.createdAt.day}/${concern.createdAt.month}/${concern.createdAt.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                            ],
                          ),
                          trailing: FilledButton(
                            // BK-PC-01: the app theme sets button
                            // minimumSize width to infinite
                            // (full-width buttons). ListTile trailing
                            // receives unbounded horizontal width, so an
                            // infinite minimum breaks _RenderListTile layout.
                            // Constrain the claim action to its natural width
                            // here; height (48) still follows the theme.
                            style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                            onPressed: () async {
                              final err = await ref.read(peerConcernControllerProvider.notifier).claim(concern.id);
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan diklaim.')));
                                ref.invalidate(counselorPeerConcernQueueProvider);
                                ref.invalidate(counselorPeerConcernHistoryProvider);
                                context.push('${AppRoutes.counselorPeerConcernQueue}/${concern.id}');
                              }
                            },
                            child: const Text('Tangani'),
                          ),
                          onTap: () => context.push('${AppRoutes.counselorPeerConcernQueue}/${concern.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // Sedang Ditangani
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: ${e.toString().replaceAll('PeerConcernException: ', '')}')),
              data: (list) {
                final reviewing = list.where((c) => c.status == 'reviewing').toList();
                if (reviewing.isEmpty) return const Center(child: Text('Tidak ada yang sedang ditangani.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: reviewing.length,
                  itemBuilder: (c, i) {
                    final concern = reviewing[i];
                    return Card(
                      child: ListTile(
                        title: Text(concern.targetDisplay),
                        subtitle: Text(concern.reasonLabel),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('${AppRoutes.counselorPeerConcernQueue}/${concern.id}'),
                      ),
                    );
                  },
                );
              },
            ),
            // Riwayat
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: ${e.toString().replaceAll('PeerConcernException: ', '')}')),
              data: (list) {
                final history = list.where((c) => c.status == 'resolved' || c.status == 'dismissed').toList();
                if (history.isEmpty) return const Center(child: Text('Belum ada riwayat.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: history.length,
                  itemBuilder: (c, i) {
                    final concern = history[i];
                    return Card(
                      child: ListTile(
                        title: Text(concern.targetDisplay),
                        subtitle: Text(
                          concern.closedAt == null
                              ? '${concern.reasonLabel} • ${concern.statusLabel}'
                              : '${concern.reasonLabel} • ${concern.statusLabel} • Ditutup ${concern.closedAt!.day}/${concern.closedAt!.month}/${concern.closedAt!.year}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('${AppRoutes.counselorPeerConcernQueue}/${concern.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
