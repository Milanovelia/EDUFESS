import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/counseling_providers.dart';

class CounselorMoodHistoryPage extends ConsumerWidget {
  const CounselorMoodHistoryPage({required this.conversationId, super.key});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(counselorMoodHistoryProvider(conversationId));
    final convAsync = ref.watch(bkConversationProvider(conversationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Mood')),
      body: Column(
        children: [
          convAsync.maybeWhen(
            data: (c) => c == null
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Siswa BK: ${c.studentAlias}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: const Text('Data ini adalah catatan perasaan yang dilaporkan sendiri oleh siswa dan bukan hasil diagnosis.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
          ),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Gagal memuat riwayat: ${e.toString().replaceAll('CounselingException: ', '')}', textAlign: TextAlign.center))),
              data: (list) {
                if (list.isEmpty) return const Center(child: Text('Belum ada riwayat mood.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final m = list[i];
                    return Card(
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
