import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/state_views.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../moderation/presentation/providers/moderation_providers.dart';

/// Profile tab showing current user info and logout.
///
/// Displays the current user's pseudonym. Provides logout which signs out
/// via Supabase Auth and redirects to `/auth/login`.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RefreshableStateView(
          onRefresh: () async => ref.invalidate(currentProfileProvider),
          child: ErrorStateView(
            title: 'Gagal memuat profil',
            message: 'Periksa koneksi kamu lalu coba lagi.',
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return RefreshableStateView(
              onRefresh: () async => ref.invalidate(currentProfileProvider),
              child: EmptyStateView(
                icon: Icons.person_off_outlined,
                title: 'Profil tidak ditemukan',
                message: 'Coba muat ulang profil kamu.',
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Muat ulang'),
                ),
              ),
            );
          }

          if (profile.pseudonym.isEmpty) {
            return RefreshableStateView(
              onRefresh: () async => ref.invalidate(currentProfileProvider),
              child: EmptyStateView(
                icon: Icons.person_outline,
                title: 'Profil belum lengkap',
                message: 'Pseudonim kamu belum tersedia.',
                action: FilledButton.tonal(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Muat ulang'),
                ),
              ),
            );
          }

          final theme = Theme.of(context);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(currentProfileProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Text(
                      profile.pseudonym[0].toUpperCase(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text(
                    profile.pseudonym,
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Center(
                  child: Text(
                    'Nama tampilan di komunitas',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: const Text('Tersimpan'),
                  subtitle: const Text('Postingan yang kamu simpan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.saved),
                ),
                Consumer(builder: (context, ref, _) {
                  final isAdminAsync = ref.watch(isAdminProvider);
                  return isAdminAsync.maybeWhen(
                    data: (isAdmin) => isAdmin
                        ? ListTile(
                            leading: const Icon(Icons.shield_outlined),
                            title: const Text('Moderasi'),
                            subtitle: const Text('Antrean laporan konten'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(AppRoutes.moderation),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  );
                }),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Tentang EduFess'),
                  subtitle: const Text('Komunitas berbagi pengetahuan sekolah'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'EduFess',
                      applicationVersion: '1.0.0',
                      children: const [
                        Text(
                          'Komunitas berbagi pengetahuan sekolah dengan '
                          'jembatan konseling yang menjaga privasi.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        ref.read(authControllerProvider.notifier).signOut();
      }
    });
  }
}
