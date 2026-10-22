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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gagal memuat: ${e.toString().replaceAll('PeerConcernException: ', '')}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(peerConcernDetailProvider(concernId)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (concern) {
          final isPending = concern.status == 'pending';
          final isReviewing = concern.status == 'reviewing';
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
                if (isPending) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final err = await ref.read(peerConcernControllerProvider.notifier).claim(concern.id);
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan berhasil diklaim.')));
                          ref.invalidate(counselorPeerConcernQueueProvider);
                          ref.invalidate(counselorPeerConcernHistoryProvider);
                          ref.invalidate(peerConcernDetailProvider(concern.id));
                        }
                      },
                      child: const Text('Tangani Laporan Ini'),
                    ),
                  ),
                ] else if (isReviewing) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final noteCtrl = TextEditingController();
                        final responseCtrl = TextEditingController();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Tandai Selesai'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(controller: responseCtrl, decoration: const InputDecoration(labelText: 'Tanggapan untuk pelapor', helperText: 'Pesan ini dapat dilihat oleh siswa yang mengirim laporan.', border: OutlineInputBorder()), maxLines: 3, maxLength: 2000),
                                  const SizedBox(height: AppSpacing.md),
                                  TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan internal BK', helperText: 'Hanya dapat dilihat oleh guru BK.', border: OutlineInputBorder()), maxLines: 3, maxLength: 2000),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Selesai')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final err = await ref.read(peerConcernControllerProvider.notifier).resolve(concern.id, note: _clean(noteCtrl.text), response: _clean(responseCtrl.text));
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
                        final responseCtrl = TextEditingController();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Tutup Tanpa Tindak Lanjut'),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(controller: responseCtrl, decoration: const InputDecoration(labelText: 'Tanggapan untuk pelapor', helperText: 'Pesan ini dapat dilihat oleh siswa yang mengirim laporan.', border: OutlineInputBorder()), maxLines: 3, maxLength: 2000),
                                  const SizedBox(height: AppSpacing.md),
                                  TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan internal BK', helperText: 'Hanya dapat dilihat oleh guru BK.', border: OutlineInputBorder()), maxLines: 3, maxLength: 2000),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tutup')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        final err = await ref.read(peerConcernControllerProvider.notifier).dismiss(concern.id, note: _clean(noteCtrl.text), response: _clean(responseCtrl.text));
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
                ] else ...[
                  const Divider(height: AppSpacing.xl),
                  Text('Penutupan', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Status akhir: ${concern.statusLabel}', style: Theme.of(context).textTheme.labelMedium),
                  if (concern.handledAt != null) Text('Ditangani: ${_date(concern.handledAt!)}', style: Theme.of(context).textTheme.labelSmall),
                  if (concern.closedAt != null) Text('Ditutup: ${_date(concern.closedAt!)}', style: Theme.of(context).textTheme.labelSmall),
                  if (concern.reporterResponse != null && concern.reporterResponse!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('TANGGAPAN UNTUK PELAPOR', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(concern.reporterResponse!),
                  ],
                  if (concern.resolutionNote != null && concern.resolutionNote!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('CATATAN INTERNAL', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                    Text(concern.resolutionNote!),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Trims optional note input; empty becomes null for the RPC.
String? _clean(String v) => v.trim().isEmpty ? null : v.trim();

/// Short day/month/year date for closure metadata.
String _date(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
