import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
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
                            final p = await showTimePicker(context: context, initialTime: _start);
                            if (p != null) setState(() => _start = p);
                          },
                          child: const Text('Pilih'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text('Selesai: ${_end.format(context)}')),
                        TextButton(
                          onPressed: () async {
                            final p = await showTimePicker(context: context, initialTime: _end);
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
