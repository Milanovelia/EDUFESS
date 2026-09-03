// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/counseling_providers.dart';
import '../../data/models/bk_appointment.dart';

class BkAppointmentsPage extends ConsumerWidget {
  const BkAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(studentAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Konseling')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Buat Janji'),
      ),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text('Gagal memuat jadwal: ${e.toString().replaceAll('CounselingException: ', '')}', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton(onPressed: () => ref.invalidate(studentAppointmentsProvider), child: const Text('Coba lagi')),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('Belum ada jadwal.\nBuat janji untuk konseling dengan guru BK.', textAlign: TextAlign.center)));
          }
          // Group: Aktif (pending, accepted), Riwayat (rejected, cancelled, completed)
          final aktif = list.where((a) => a.status == 'pending' || a.status == 'accepted').toList();
          final riwayat = list.where((a) => a.status == 'rejected' || a.status == 'cancelled' || a.status == 'completed').toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(studentAppointmentsProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (aktif.isNotEmpty) ...[
                  Text('Jadwal Aktif', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  ...aktif.map((a) => _StudentAppointmentCard(appointment: a)),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (riwayat.isNotEmpty) ...[
                  Text('Riwayat', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.sm),
                  ...riwayat.map((a) => _StudentAppointmentCard(appointment: a)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    // Use a dialog to select slot
    final selected = await showDialog<CounselorSlot>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Jadwal'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder<List<CounselorSlot>>(
            future: ref.read(counselingRepositoryProvider).fetchAvailableSlots(),
            builder: (c, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) return Center(child: Text('Gagal memuat slot: ${snap.error}'));
              final slots = snap.data ?? [];
              if (slots.isEmpty) return const Center(child: Text('Tidak ada slot tersedia.'));
              return ListView.builder(
                itemCount: slots.length,
                itemBuilder: (c, i) {
                  final s = slots[i];
                  return ListTile(
                    title: Text(s.dateLabel),
                    subtitle: Text('${s.timeLabel} • ${s.counselorDisplay}'),
                    onTap: () => Navigator.pop(ctx, s),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal'))],
      ),
    );
    if (selected == null) return;
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Janji'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tanggal: ${selected.dateLabel}\nWaktu: ${selected.timeLabel}\nGuru: ${selected.counselorDisplay}'),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()), maxLines: 2, maxLength: 1000),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buat Janji')),
        ],
      ),
    );
    if (confirm != true) return;
    final err = await ref.read(counselingControllerProvider.notifier).requestAppointment(availabilityId: selected.availabilityId, studentNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Janji berhasil dibuat.')));
    }
  }
}

class _StudentAppointmentCard extends ConsumerWidget {
  const _StudentAppointmentCard({required this.appointment});
  final BkAppointment appointment;

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'accepted':
        return 'Terjadwal';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      case 'completed':
        return 'Selesai';
      default:
        return s;
    }
  }

  String _format(DateTime dt) => '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canCancel = appointment.status == 'pending' || appointment.status == 'accepted';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(label: Text(_statusLabel(appointment.status), style: theme.textTheme.labelSmall)),
                const Spacer(),
                Text(_format(appointment.requestedStartAt), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Guru BK: ${appointment.counselorDisplay ?? 'Guru BK'}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (appointment.scheduledStartAt != null) ...[
              const SizedBox(height: 4),
              Text('Terjadwal: ${_format(appointment.scheduledStartAt!)} - ${_format(appointment.scheduledEndAt!)}', style: theme.textTheme.bodySmall),
            ],
            if (appointment.studentNote != null) ...[
              const SizedBox(height: 4),
              Text('Catatan: ${appointment.studentNote}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (canCancel) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Batalkan Janji'),
                      content: const Text('Batalkan jadwal konseling ini?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Batalkan')),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  final err = await ref.read(counselingControllerProvider.notifier).cancelStudentAppointment(appointment.appointmentId);
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Janji dibatalkan.')));
                  }
                },
                child: const Text('Batalkan Janji'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
