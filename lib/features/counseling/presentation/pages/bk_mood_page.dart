import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/counseling_providers.dart';

class BkMoodPage extends ConsumerStatefulWidget {
  const BkMoodPage({super.key});

  @override
  ConsumerState<BkMoodPage> createState() => _BkMoodPageState();
}

class _BkMoodPageState extends ConsumerState<BkMoodPage> {
  int? _selectedMood;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(studentMoodHistoryProvider);
    final isLoading = ref.watch(moodControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Mood Check-In')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Mood Check-In membantu kamu mencatat perasaanmu dari waktu ke waktu. Fitur ini bukan alat diagnosis atau layanan medis.'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Bagaimana perasaanmu?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _MoodChip(label: 'Sangat Buruk', emoji: '😞', value: 1, selected: _selectedMood == 1, onTap: () => setState(() => _selectedMood = 1)),
                _MoodChip(label: 'Buruk', emoji: '🙁', value: 2, selected: _selectedMood == 2, onTap: () => setState(() => _selectedMood = 2)),
                _MoodChip(label: 'Biasa', emoji: '😐', value: 3, selected: _selectedMood == 3, onTap: () => setState(() => _selectedMood = 3)),
                _MoodChip(label: 'Baik', emoji: '🙂', value: 4, selected: _selectedMood == 4, onTap: () => setState(() => _selectedMood = 4)),
                _MoodChip(label: 'Sangat Baik', emoji: '😄', value: 5, selected: _selectedMood == 5, onTap: () => setState(() => _selectedMood = 5)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Ceritakan sedikit jika kamu ingin. (opsional)', border: OutlineInputBorder()),
              maxLines: 3,
              maxLength: 1000,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading || _selectedMood == null
                    ? null
                    : () async {
                        final err = await ref.read(moodControllerProvider.notifier).submit(moodLevel: _selectedMood!, note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim());
                        if (err != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in berhasil disimpan.')));
                          setState(() => _selectedMood = null);
                          _noteCtrl.clear();
                        }
                      },
                child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan Check-In'),
              ),
            ),
            if (_selectedMood != null && _selectedMood! <= 2) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(AppRadius.md)),
                child: const Text('Kalau kamu ingin berbicara lebih lanjut, kamu bisa menggunakan Ruang BK.'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Riwayat Mood', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat riwayat: ${e.toString().replaceAll('CounselingException: ', '')}')),
              data: (list) {
                if (list.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('Belum ada riwayat mood.', textAlign: TextAlign.center)));
                return Column(
                  children: [
                    // Simple trend: last 7
                    if (list.length >= 2) ...[
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: list.length > 7 ? 7 : list.length,
                          itemBuilder: (c, i) {
                            final m = list[i];
                            return Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(m.emoji, style: const TextStyle(fontSize: 24)),
                                  Text('${m.moodLevel}', style: Theme.of(context).textTheme.labelSmall),
                                  Text('${m.checkedInAt.day}/${m.checkedInAt.month}', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    ...list.map((m) => Card(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            leading: Text(m.emoji, style: const TextStyle(fontSize: 24)),
                            title: Text(m.label),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${m.checkedInAt.day}/${m.checkedInAt.month}/${m.checkedInAt.year} ${m.checkedInAt.hour.toString().padLeft(2, '0')}:${m.checkedInAt.minute.toString().padLeft(2, '0')}'),
                                if (m.note != null) Text(m.note!, style: const TextStyle(fontStyle: FontStyle.italic)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Hapus check-in',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Hapus Check-In?'),
                                    content: const Text('Check-in ini akan dihapus dari riwayatmu.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  final err = await ref.read(moodControllerProvider.notifier).deleteMoodCheckin(m.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(err ?? 'Check-in berhasil dihapus.')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.label, required this.emoji, required this.value, required this.selected, required this.onTap});
  final String label;
  final String emoji;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$emoji $label'),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
