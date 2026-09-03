import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

/// Profile tab showing current user info and logout.
///
/// Displays pseudonym and role from the loaded profile. Provides logout
/// which signs out via Supabase Auth and redirects to `/auth/login`.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Gagal memuat profil.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$e',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(
              child: Text('Profil tidak ditemukan.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  child: Text(
                    profile.pseudonym.isNotEmpty
                        ? profile.pseudonym[0].toUpperCase()
                        : '?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  profile.pseudonym,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Chip(
                  label: Text(profile.role.toUpperCase()),
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
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Tentang EduFess'),
                subtitle: const Text('M1 C2 — Authentication Foundation'),
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
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonal(
                onPressed: () => _confirmLogout(context, ref),
                child: const Text('Keluar'),
              ),
            ],
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
