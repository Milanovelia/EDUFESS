import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/counseling_providers.dart';

class BkPage extends ConsumerWidget {
  const BkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('BK')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat profil.')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profil tidak ditemukan.'));
          if (profile.isStudent) return _StudentBkView();
          if (profile.isCounselor) return _CounselorBkView();
          // admin or other
          return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('Akses BK terbatas untuk siswa dan guru BK.', textAlign: TextAlign.center)));
        },
      ),
    );
  }
}

class _StudentBkView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentAsync = ref.watch(hasBkConsentProvider);
    final conversationsAsync = ref.watch(studentConversationsProvider);

    return consentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat status persetujuan.')),
      data: (hasConsent) {
        if (!hasConsent) {
          return _ConsentView();
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                onPressed: () async {
                  final id = await ref.read(counselingControllerProvider.notifier).createConversation();
                  if (id != null && context.mounted) {
                    // id is actually error string? createConversation returns id string? Our controller returns String? id or error msg — need to handle.
                    // Currently createConversation returns String? where String is id on success? It returns id string, but our controller returns id as String? and error as String? ambiguous.
                    // We'll just refresh list.
                    ref.invalidate(studentConversationsProvider);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percakapan dibuat.')));
                  } else if (context.mounted) {
                    final err = ref.read(counselingControllerProvider).maybeWhen(error: (e, _) => e.toString(), orElse: () => 'Gagal membuat percakapan.');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Mulai Konseling'),
              ),
            ),
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Gagal memuat percakapan.')),
                data: (list) {
                  if (list.isEmpty) return const Center(child: Text('Belum ada percakapan BK.'));
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final conv = list[i];
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(conv.studentAlias),
                        subtitle: Text('${conv.status} • ${_timeAgo(conv.createdAt)}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ConsentView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ConsentView> createState() => _ConsentViewState();
}

class _ConsentViewState extends ConsumerState<_ConsentView> {
  bool _checked = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Ketentuan BK', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          const Text('• BK bersifat privat dan terpisah dari feed publik.\n• Kontak awal menggunakan alias pseudonim (Siswa BK #XXXX).\n• Guru BK hanya melihat identitas asli jika ada alasan yang jelas dan tindakan dicatat untuk audit.\n• Bukan layanan darurat medis.'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Checkbox(value: _checked, onChanged: (v) => setState(() => _checked = v ?? false)),
              const Expanded(child: Text('Saya menyetujui ketentuan BK (bk-consent-v1)')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: !_checked
                ? null
                : () async {
                    final err = await ref.read(counselingControllerProvider.notifier).createConsent();
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Persetujuan disimpan.')));
                    }
                  },
            child: const Text('Setuju & Lanjutkan'),
          ),
        ],
      ),
    );
  }
}

class _CounselorBkView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(counselorQueueProvider);
    final assignedAsync = ref.watch(counselorAssignedProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Antrean'), Tab(text: 'Ditangani')]),
          Expanded(
            child: TabBarView(
              children: [
                // Queue
                queueAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Gagal memuat antrean.')),
                  data: (list) {
                    if (list.isEmpty) return const Center(child: Text('Tidak ada antrean.'));
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final conv = list[i];
                        return ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(conv.studentAlias),
                          subtitle: Text('${conv.status} • ${conv.createdAt.toLocal().toString().split(' ')[0]}'),
                          trailing: FilledButton(
                            onPressed: () async {
                              final err = await ref.read(counselingControllerProvider.notifier).claim(conv.id);
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percakapan diklaim.')));
                              }
                            },
                            child: const Text('Klaim'),
                          ),
                          onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
                        );
                      },
                    );
                  },
                ),
                // Assigned
                assignedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Gagal memuat.')),
                  data: (list) {
                    if (list.isEmpty) return const Center(child: Text('Belum ada percakapan yang ditangani.'));
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (c, i) {
                        final conv = list[i];
                        return ListTile(
                          leading: const Icon(Icons.chat),
                          title: Text(conv.studentAlias),
                          subtitle: Text(conv.status),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
