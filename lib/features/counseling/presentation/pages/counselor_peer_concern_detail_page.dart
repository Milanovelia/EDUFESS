import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/peer_concern_providers.dart';

class CounselorPeerConcernDetailPage extends ConsumerWidget {
  const CounselorPeerConcernDetailPage({required this.concernId, super.key});
  final String concernId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(peerConcernDetailProvider(concernId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Peduli Teman')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Gagal memuat: ${e.toString().replaceAll('PeerConcernException: ', '')}', textAlign: TextAlign.center))),
        data: (concern) {
          final isPendingOrReviewing = concern.status == 'pending' || concern.status == 'reviewing';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(concern.targetDisplay, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Chip(label: Text(concern.reasonLabel)),
                const SizedBox(height: AppSpacing.sm),
                Text('Status: ${concern.statusLabel}', style: Theme.of(context).textTheme.labelMedium),
                Text('Tanggal: ${concern.createdAt.day}/${concern.createdAt.month}/${concern.createdAt.year}', style: Theme.of(context).textTheme.labelSmall),
                const Divider(height: AppSpacing.xl),
                if (concern.details != null) ...[
                  Text('Detail:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text(concern.details!),
                ] else
                  const Text('Tidak ada detail.'),
                const SizedBox(height: AppSpacing.xl),
                if (isPendingOrReviewing) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final noteCtrl = TextEditingController();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Tandai Selesai'),
                            content: TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan penanganan (opsional)', border: OutlineInputBorder()), maxLines: 3),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Selesai')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final err = await ref.read(peerConcernControllerProvider.notifier).resolve(concern.id, note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan diselesaikan.')));
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Tandai Selesai'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final noteCtrl = TextEditingController();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Tutup Tanpa Tindak Lanjut'),
                            content: TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()), maxLines: 3),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tutup')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final err = await ref.read(peerConcernControllerProvider.notifier).dismiss(concern.id, note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan ditutup.')));
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Tutup Tanpa Tindak Lanjut'),
                    ),
                  ),
                ] else
                  const Text('Laporan ini sudah ditangani.', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          );
        },
      ),
    );
  }
}
