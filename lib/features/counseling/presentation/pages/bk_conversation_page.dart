import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/counseling_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class BkConversationPage extends ConsumerStatefulWidget {
  const BkConversationPage({required this.conversationId, super.key});
  final String conversationId;

  @override
  ConsumerState<BkConversationPage> createState() => _BkConversationPageState();
}

class _BkConversationPageState extends ConsumerState<BkConversationPage> {
  final _controller = TextEditingController();
  String? _revealedPseudonym;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(counselingMessagesProvider(widget.conversationId));
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konseling'),
        actions: [
          profileAsync.maybeWhen(
            data: (p) => p?.isCounselor == true
                ? IconButton(
                    icon: const Icon(Icons.visibility),
                    tooltip: 'Reveal identity',
                    onPressed: () async {
                      final reasonCtrl = TextEditingController();
                      final reason = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Akses Identitas'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Akses identitas siswa akan dicatat untuk keperluan audit.'),
                              const SizedBox(height: AppSpacing.md),
                              TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Alasan *', border: OutlineInputBorder()), maxLines: 2),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                            FilledButton(
                                onPressed: () {
                                  if (reasonCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Alasan wajib diisi.')));
                                    return;
                                  }
                                  Navigator.pop(ctx, reasonCtrl.text.trim());
                                },
                                child: const Text('Konfirmasi')),
                          ],
                        ),
                      );
                      if (reason == null) return;
                      final res = await ref.read(counselingControllerProvider.notifier).reveal(conversationId: widget.conversationId, reason: reason);
                      if (res != null && context.mounted) {
                        setState(() => _revealedPseudonym = res.pseudonym);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Identitas: ${res.pseudonym}')));
                      } else if (context.mounted) {
                        final err = ref.read(counselingControllerProvider).maybeWhen(error: (e, _) => e.toString(), orElse: () => 'Akses identitas gagal.');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_revealedPseudonym != null)
            Container(
              width: double.infinity,
              color: Colors.amber.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text('Identitas terungkap: $_revealedPseudonym', style: Theme.of(context).textTheme.labelMedium),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString().contains('CounselingException') ? e.toString().replaceAll('CounselingException: ', '') : 'Gagal memuat pesan.')),
              data: (messages) {
                if (messages.isEmpty) return const Center(child: Text('Belum ada pesan.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  itemBuilder: (c, i) {
                    final m = messages[i];
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(m.content),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Tulis pesan...', border: OutlineInputBorder()),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () async {
                    final txt = _controller.text.trim();
                    if (txt.isEmpty) return;
                    final err = await ref.read(counselingControllerProvider.notifier).sendMessage(conversationId: widget.conversationId, content: txt);
                    if (err == null) {
                      _controller.clear();
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                  child: const Text('Kirim'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
