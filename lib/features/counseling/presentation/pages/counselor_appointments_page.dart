// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/counseling_providers.dart';
import '../../data/models/bk_appointment.dart';

class CounselorAppointmentsPage extends ConsumerWidget {
  const CounselorAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(counselorAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal BK')),
      body: appointmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: ${e.toString().replaceAll('CounselingException: ', '')}')),
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('Belum ada jadwal.'));
          final pending = list.where((a) => a.status == 'pending').toList();
          final scheduled = list.where((a) => a.status == 'accepted').toList();
          final history = list.where((a) => a.status == 'rejected' || a.status == 'cancelled' || a.status == 'completed').toList();
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                const TabBar(tabs: [Tab(text: 'Permintaan'), Tab(text: 'Terjadwal'), Tab(text: 'Riwayat')]),
                Expanded(
                  child: TabBarView(
                    children: [
                      _List(pending, empty: 'Tidak ada permintaan.'),
                      _List(scheduled, empty: 'Tidak ada jadwal ter-jadwal.'),
                      _List(history, empty: 'Tidak ada riwayat.'),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List(this.list, {required this.empty});
  final List<BkAppointment> list;
  final String empty;

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Permintaan';
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

  String _fmt(DateTime dt) => '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isEmpty) return Center(child: Text(empty));
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: list.length,
      itemBuilder: (c, i) {
        final a = list[i];
        return Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(label: Text(_statusLabel(a.status))),
                    const Spacer(),
                    Text(_fmt(a.requestedStartAt), style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Siswa: ${a.studentAlias ?? 'Siswa BK'}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (a.studentNote != null) Text('Catatan: ${a.studentNote}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                if (a.scheduledStartAt != null) Text('Terjadwal: ${_fmt(a.scheduledStartAt!)}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (a.status == 'pending') ...[
                      FilledButton(
                        onPressed: () async {
                          final err = await ref.read(counselingControllerProvider.notifier).acceptAppointment(a.appointmentId);
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        },
                        child: const Text('Terima'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final err = await ref.read(counselingControllerProvider.notifier).rejectAppointment(a.appointmentId);
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        },
                        child: const Text('Tolak'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final newDate = await showDatePicker(context: context, initialDate: a.requestedStartAt, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
                          if (newDate == null) return;
                          final start = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(a.requestedStartAt));
                          if (start == null) return;
                          final end = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(a.requestedEndAt));
                          if (end == null) return;
                          final newStart = DateTime(newDate.year, newDate.month, newDate.day, start.hour, start.minute);
                          final newEnd = DateTime(newDate.year, newDate.month, newDate.day, end.hour, end.minute);
                          final err = await ref.read(counselingControllerProvider.notifier).rescheduleAppointment(appointmentId: a.appointmentId, newStart: newStart, newEnd: newEnd);
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        },
                        child: const Text('Atur Ulang'),
                      ),
                    ],
                    if (a.status == 'accepted') ...[
                      OutlinedButton(
                        onPressed: () async {
                          final newDate = await showDatePicker(context: context, initialDate: a.scheduledStartAt ?? a.requestedStartAt, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
                          if (newDate == null) return;
                          final start = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(a.scheduledStartAt ?? a.requestedStartAt));
                          if (start == null) return;
                          final end = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(a.scheduledEndAt ?? a.requestedEndAt));
                          if (end == null) return;
                          final newStart = DateTime(newDate.year, newDate.month, newDate.day, start.hour, start.minute);
                          final newEnd = DateTime(newDate.year, newDate.month, newDate.day, end.hour, end.minute);
                          final err = await ref.read(counselingControllerProvider.notifier).rescheduleAppointment(appointmentId: a.appointmentId, newStart: newStart, newEnd: newEnd);
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        },
                        child: const Text('Atur Ulang'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final err = await ref.read(counselingControllerProvider.notifier).cancelCounselorAppointment(a.appointmentId);
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        },
                        child: const Text('Batalkan'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          final err = await ref.read(counselingControllerProvider.notifier).completeAppointment(a.appointmentId);
                          if (err != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        },
                        child: const Text('Tandai Selesai'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
