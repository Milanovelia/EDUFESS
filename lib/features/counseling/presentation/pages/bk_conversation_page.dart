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

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'Menunggu Guru BK';
      case 'assigned':
        return 'Sedang Ditangani';
      case 'closed':
        return 'Selesai';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(counselingMessagesProvider(widget.conversationId));
    final convAsync = ref.watch(bkConversationProvider(widget.conversationId));
    final profileAsync = ref.watch(currentProfileProvider);

    final isClosed = convAsync.maybeWhen(data: (c) => c?.isClosed ?? false, orElse: () => false);

    return Scaffold(
      appBar: AppBar(
        title: convAsync.maybeWhen(
          data: (c) => Text(c == null ? 'Konseling' : 'Konseling • ${c.studentAlias}'),
          orElse: () => const Text('Konseling'),
        ),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.replaceAll('CounselingException: ', ''))));
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
          convAsync.maybeWhen(
            data: (c) => c == null
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Identitas BK kamu: ${c.studentAlias}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Status: ${_statusLabel(c.status)}', style: Theme.of(context).textTheme.labelSmall),
                        if (c.isClosed) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadius.sm)),
                            child: const Text('Percakapan ini telah selesai. Kamu hanya dapat membaca riwayat.', style: TextStyle(fontStyle: FontStyle.italic)),
                          ),
                        ],
                      ],
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
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
              error: (e, _) => Center(
                  child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text(e.toString().contains('CounselingException') ? e.toString().replaceAll('CounselingException: ', '') : 'Gagal memuat pesan.', textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: () => ref.invalidate(counselingMessagesProvider(widget.conversationId)), child: const Text('Coba lagi')),
                  ],
                ),
              )),
              data: (messages) {
                if (messages.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(counselingMessagesProvider(widget.conversationId)),
                    child: ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Belum ada pesan.\nKamu bisa memulai percakapan di sini.', textAlign: TextAlign.center)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(counselingMessagesProvider(widget.conversationId)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (c, i) {
                      final m = messages[i];
                      final isMine = m.isMine ?? false;
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isMine ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.content, style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text(_timeAgo(m.createdAt), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (isClosed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              color: Colors.grey.withValues(alpha: 0.1),
              child: const Text('Percakapan ini telah selesai.', textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic)),
            )
          else
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
                      maxLength: 4000,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Consumer(builder: (context, ref, _) {
                    final loading = ref.watch(counselingControllerProvider).isLoading;
                    return FilledButton(
                      onPressed: loading
                          ? null
                          : () async {
                              final txt = _controller.text.trim();
                              if (txt.isEmpty || txt.length > 4000) {
                                if (txt.isEmpty) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesan 1..4000 karakter.')));
                                return;
                              }
                              final err = await ref.read(counselingControllerProvider.notifier).sendMessage(conversationId: widget.conversationId, content: txt);
                              if (err == null) {
                                _controller.clear();
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                              }
                            },
                      child: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Kirim'),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
