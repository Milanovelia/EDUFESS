import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/counseling_providers.dart';
import '../../data/models/bk_conversation.dart';

class BkPage extends ConsumerWidget {
  const BkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('BK')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Gagal memuat profil.')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profil tidak ditemukan.'));
          if (profile.isStudent) return const _StudentBkView();
          if (profile.isCounselor) return const _CounselorBkView();
          return const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Text('Akses BK terbatas untuk siswa dan guru BK.', textAlign: TextAlign.center)));
        },
      ),
    );
  }
}

class _StudentBkView extends ConsumerWidget {
  const _StudentBkView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentAsync = ref.watch(hasBkConsentProvider);
    final conversationsAsync = ref.watch(studentConversationsProvider);

    return consentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Gagal memuat status persetujuan: ${e.toString().replaceAll('Exception: ', '')}')),
      data: (hasConsent) {
        if (!hasConsent) {
          return const _ConsentView();
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(studentConversationsProvider);
            await ref.read(studentConversationsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PrivacyCard(),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bagaimana perasaanmu hari ini?', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: AppSpacing.sm),
                        const Text('Isi Mood Check-In untuk mencatat perasaanmu.'),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push(AppRoutes.bkMood),
                            icon: const Icon(Icons.mood_outlined),
                            label: const Text('Isi Mood Check-In'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.bkAppointments),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Jadwal Konseling'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _StartCounselingButton(),
                const SizedBox(height: AppSpacing.lg),
                Text('Percakapan Saya', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                conversationsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Gagal memuat percakapan: ${e.toString().replaceAll('CounselingException: ', '')}')),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: Text('Belum ada percakapan BK.\nMulai percakapan jika kamu ingin berbicara dengan guru BK.', textAlign: TextAlign.center)),
                      );
                    }
                    // Sort by updatedAt desc (already from RPC), then group
                    final active = list.where((c) => c.isActive).toList();
                    final history = list.where((c) => c.isClosed).toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (active.isNotEmpty) ...[
                          const Text('Aktif', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSpacing.sm),
                          ...active.map((c) => _ConversationCard(conv: c)),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (history.isNotEmpty) ...[
                          const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSpacing.sm),
                          ...history.map((c) => _ConversationCard(conv: c)),
                        ],
                        if (active.isEmpty && history.isEmpty)
                          ...list.map((c) => _ConversationCard(conv: c)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.privacy_tip_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: AppSpacing.sm), Text('Ruang BK', style: Theme.of(context).textTheme.titleSmall)]),
            const SizedBox(height: AppSpacing.sm),
            const Text('Kamu dapat memulai percakapan dengan identitas BK samaran. Guru BK hanya dapat membuka identitasmu melalui akses yang berwenang dan tercatat. Percakapan BK bersifat privat dan terpisah dari feed publik. BK bukan layanan darurat medis.'),
          ],
        ),
      ),
    );
  }
}

class _StartCounselingButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(studentConversationsProvider);
    final isLoading = ref.watch(counselingControllerProvider).isLoading;
    return conversationsAsync.maybeWhen(
      data: (list) {
        final active = list.where((c) => c.isActive).toList();
        final hasActive = active.isNotEmpty;
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isLoading
                ? null
                : () async {
                    if (hasActive) {
                      // Open existing active conversation instead of creating new
                      context.push('${AppRoutes.bk}/${active.first.id}');
                      return;
                    }
                    final id = await ref.read(counselingControllerProvider.notifier).createConversation();
                    if (id != null && context.mounted) {
                      ref.invalidate(studentConversationsProvider);
                      context.push('${AppRoutes.bk}/$id');
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percakapan dibuat.')));
                    } else if (context.mounted) {
                      final err = ref.read(counselingControllerProvider).maybeWhen(error: (e, _) => e.toString(), orElse: () => 'Gagal membuat percakapan.');
                      // If error is about already having active, try to open it
                      if (err.contains('sudah memiliki percakapan aktif')) {
                        if (active.isNotEmpty) context.push('${AppRoutes.bk}/${active.first.id}');
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.replaceAll('CounselingException: ', '').replaceAll('Exception: ', ''))));
                    }
                  },
            icon: Icon(hasActive ? Icons.chat : Icons.add),
            label: Text(hasActive ? 'Buka Percakapan Aktif' : 'Mulai Konseling'),
          ),
        );
      },
      orElse: () => SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isLoading
              ? null
              : () async {
                  final id = await ref.read(counselingControllerProvider.notifier).createConversation();
                  if (id != null && context.mounted) {
                    ref.invalidate(studentConversationsProvider);
                    context.push('${AppRoutes.bk}/$id');
                  } else if (context.mounted) {
                    final err = ref.read(counselingControllerProvider).maybeWhen(error: (e, _) => e.toString(), orElse: () => 'Gagal membuat percakapan.');
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.replaceAll('CounselingException: ', ''))));
                  }
                },
          icon: const Icon(Icons.add),
          label: const Text('Mulai Konseling'),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conv});
  final BkConversation conv;

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
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: Icon(conv.isClosed ? Icons.check_circle_outline : Icons.chat_bubble_outline, color: conv.isClosed ? Colors.grey : Theme.of(context).colorScheme.primary),
        title: Text('Identitas BK kamu: ${conv.studentAlias}', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(_statusLabel(conv.status), style: Theme.of(context).textTheme.labelSmall),
            Text('${_timeAgo(conv.updatedAt)} • ${conv.createdAt.day}/${conv.createdAt.month}/${conv.createdAt.year}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
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

class _ConsentView extends ConsumerStatefulWidget {
  const _ConsentView();

  @override
  ConsumerState<_ConsentView> createState() => _ConsentViewState();
}

class _ConsentViewState extends ConsumerState<_ConsentView> {
  bool _checked = false;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 48),
          const SizedBox(height: AppSpacing.md),
          Text('Ketentuan BK', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          const Text('Layanan BK bersifat privat dan terpisah dari feed publik.\n\n• Kontak awal menggunakan identitas samaran BK (Siswa BK #XXXX).\n• Guru BK tidak otomatis melihat identitas aslimu.\n• Dalam kondisi yang memerlukan penanganan lebih lanjut, guru BK yang menangani percakapan dapat membuka identitas melalui akses yang berwenang dan tercatat untuk audit.\n• BK bukan layanan darurat medis.'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Checkbox(value: _checked, onChanged: (v) => setState(() => _checked = v ?? false)),
              const Expanded(child: Text('Saya menyetujui ketentuan BK (bk-consent-v1)')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
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
              child: const Text('Saya Setuju dan Lanjutkan'),
            ),
          ),
          if (!_checked) const Padding(padding: EdgeInsets.only(top: AppSpacing.md), child: Text('Setujui ketentuan BK sebelum memulai percakapan.', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }
}

class _CounselorBkView extends ConsumerWidget {
  const _CounselorBkView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(counselorQueueProvider);
    final assignedAsync = ref.watch(counselorAssignedProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.counselorAvailability),
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Ketersediaan Saya'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.counselorAppointments),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Jadwal BK'),
                  ),
                ),
              ],
            ),
          ),
          const TabBar(tabs: [Tab(text: 'Antrean'), Tab(text: 'Ditangani')]),
          Expanded(
            child: TabBarView(
              children: [
                queueAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text('Gagal memuat antrean: ${e.toString().replaceAll('CounselingException: ', '')}', textAlign: TextAlign.center))),
                  data: (list) {
                    if (list.isEmpty) return const Center(child: Text('Tidak ada percakapan yang menunggu.'));
                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(counselorQueueProvider),
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final conv = list[i];
                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(conv.studentAlias),
                            subtitle: Text('Menunggu penanganan • ${_timeAgo(conv.createdAt)}'),
                            trailing: Consumer(builder: (context, ref, _) {
                              final loading = ref.watch(counselingControllerProvider).isLoading;
                              return FilledButton(
                                onPressed: loading
                                    ? null
                                    : () async {
                                        final err = await ref.read(counselingControllerProvider.notifier).claim(conv.id);
                                        if (err != null && context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                                        } else if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percakapan diklaim.')));
                                          ref.invalidate(counselorAssignedProvider);
                                          if (context.mounted) context.push('${AppRoutes.bk}/${conv.id}');
                                        }
                                      },
                                child: const Text('Tangani'),
                              );
                            }),
                            onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
                          );
                        },
                      ),
                    );
                  },
                ),
                assignedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Gagal memuat: ${e.toString().replaceAll('CounselingException: ', '')}')),
                  data: (list) {
                    if (list.isEmpty) return const Center(child: Text('Belum ada percakapan yang sedang kamu tangani.'));
                    final active = list.where((c) => c.status == 'assigned').toList();
                    final history = list.where((c) => c.status == 'closed').toList();
                    return RefreshIndicator(
                      onRefresh: () async => ref.invalidate(counselorAssignedProvider),
                      child: ListView(
                        children: [
                          if (active.isNotEmpty) ...[
                            const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Aktif', style: TextStyle(fontWeight: FontWeight.w600))),
                            ...active.map((conv) => ListTile(
                                  leading: const Icon(Icons.chat),
                                  title: Text(conv.studentAlias),
                                  subtitle: Text('${_statusLabel(conv.status)} • ${_timeAgo(conv.updatedAt)}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
                                )),
                          ],
                          if (history.isNotEmpty) ...[
                            const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Text('Riwayat', style: TextStyle(fontWeight: FontWeight.w600))),
                            ...history.map((conv) => ListTile(
                                  leading: const Icon(Icons.history, color: Colors.grey),
                                  title: Text(conv.studentAlias),
                                  subtitle: Text('Selesai • ${_timeAgo(conv.closedAt ?? conv.updatedAt)}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
                                )),
                          ],
                          if (active.isEmpty && history.isEmpty)
                            ...list.map((conv) => ListTile(
                                  leading: const Icon(Icons.chat),
                                  title: Text(conv.studentAlias),
                                  subtitle: Text(_statusLabel(conv.status)),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push('${AppRoutes.bk}/${conv.id}'),
                                )),
                        ],
                      ),
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

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'Menunggu';
      case 'assigned':
        return 'Ditangani';
      case 'closed':
        return 'Selesai';
      default:
        return s;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
