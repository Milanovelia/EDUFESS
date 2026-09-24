import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/models/bk_appointment.dart';
import '../providers/counseling_providers.dart';

class CounselorAvailabilityPage extends ConsumerStatefulWidget {
  const CounselorAvailabilityPage({super.key});

  @override
  ConsumerState<CounselorAvailabilityPage> createState() => _CounselorAvailabilityPageState();
}

class _CounselorAvailabilityPageState extends ConsumerState<CounselorAvailabilityPage> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  TimeOfDay _parseTime(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// Only active, non-past slots are manageable. Past/inactive rows are
  /// read-only history; booked protection is enforced server-side.
  bool _manageable(CounselorAvailability a) {
    if (!a.isActive) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = a.availableDate;
    return !DateTime(d.year, d.month, d.day).isBefore(today);
  }

  /// Time picker constrained to dial mode (BK-APPT-04).
  ///
  /// The framework keyboard/input mode crashes inside small or
  /// keyboard-shrunk viewports (invalid constraints); dial mode is
  /// device-verified working, so input mode is not offered here.
  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref, CounselorAvailability a) async {
    var date = DateTime(a.availableDate.year, a.availableDate.month, a.availableDate.day);
    var start = _parseTime(a.startTime);
    var end = _parseTime(a.endTime);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Edit Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tanggal: ${date.day}/${date.month}/${date.year}'),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
                  if (picked != null) setD(() => date = picked);
                },
                child: const Text('Pilih Tanggal'),
              ),
              Text('Mulai: ${start.format(ctx)}'),
              TextButton(
                onPressed: () async {
                  final p = await _pickTime(ctx, start);
                  if (p != null) setD(() => start = p);
                },
                child: const Text('Pilih Mulai'),
              ),
              Text('Selesai: ${end.format(ctx)}'),
              TextButton(
                onPressed: () async {
                  final p = await _pickTime(ctx, end);
                  if (p != null) setD(() => end = p);
                },
                child: const Text('Pilih Selesai'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (start.hour * 60 + start.minute >= end.hour * 60 + end.minute) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Waktu tidak valid.')));
                  return;
                }
                final err = await ref.read(counselingControllerProvider.notifier).updateAvailability(availabilityId: a.id, date: date, startTime: _fmt(start), endTime: _fmt(end));
                if (!ctx.mounted) return;
                if (err != null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err)));
                } else {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot diubah.')));
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref, CounselorAvailability a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Slot'),
        content: const Text('Slot tidak akan muncul di pencarian siswa. Janji yang sudah ada tidak ikut berubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final err = await ref.read(counselingControllerProvider.notifier).deactivateAvailability(a.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Slot dinonaktifkan.')));
  }
  @override
  Widget build(BuildContext context) {
    final availAsync = ref.watch(myAvailabilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ketersediaan Saya')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Tanggal: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}')),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
                            if (picked != null) setState(() => _selectedDate = picked);
                          },
                          child: const Text('Pilih Tanggal'),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Text('Mulai: ${_start.format(context)}')),
                        TextButton(
                          onPressed: () async {
                            final p = await _pickTime(context, _start);
                            if (p != null) setState(() => _start = p);
                          },
                          child: const Text('Pilih'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text('Selesai: ${_end.format(context)}')),
                        TextButton(
                          onPressed: () async {
                            final p = await _pickTime(context, _end);
                            if (p != null) setState(() => _end = p);
                          },
                          child: const Text('Pilih'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (_start.hour * 60 + _start.minute >= _end.hour * 60 + _end.minute) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waktu tidak valid.')));
                            return;
                          }
                          final err = await ref.read(counselingControllerProvider.notifier).createAvailability(date: _selectedDate, startTime: _fmt(_start), endTime: _fmt(_end));
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot ditambahkan.')));
                          }
                        },
                        child: const Text('Tambah Slot'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: availAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat: ${e.toString().replaceAll('CounselingException: ', '')}')),
              data: (list) {
                if (list.isEmpty) return const Center(child: Text('Belum ada slot.'));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final a = list[i];
                    return ListTile(
                      leading: Icon(a.isActive ? Icons.check_circle : Icons.cancel, color: a.isActive ? Colors.green : Colors.grey),
                      title: Text('${a.availableDate.day}/${a.availableDate.month}/${a.availableDate.year}'),
                      subtitle: Text('${a.startTime} - ${a.endTime} ${a.isActive ? '' : '(nonaktif)'}'),
                      trailing: !_manageable(a)
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _showEditDialog(context, ref, a);
                                } else if (v == 'deactivate') {
                                  _confirmDeactivate(context, ref, a);
                                }
                              },
                              itemBuilder: (c) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'deactivate', child: Text('Nonaktifkan')),
                              ],
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
