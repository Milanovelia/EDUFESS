import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/app_spacing.dart';
import '../providers/feed_providers.dart';
import '../widgets/post_card.dart';

/// Home feed — basic knowledge feed with loading/empty/error + pull-to-refresh.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(feedPostsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EduFess',
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: AppSpacing.md),
                const Text('Gagal memuat feed.', textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(feedPostsProvider),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(feedPostsProvider),
              child: ListView(
                children: const [
                  _ComposerEntry(),
                  SizedBox(height: 120),
                  Icon(Icons.inbox_outlined, size: 48),
                  SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text(
                      'Belum ada post. Jadilah yang pertama berbagi!',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(feedPostsProvider),
            child: ListView.builder(
              itemCount: posts.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return const _ComposerEntry();
                return PostCard(post: posts[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Lightweight tappable entry opening the existing create-post flow.
class _ComposerEntry extends StatelessWidget {
  const _ComposerEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: InkWell(
        onTap: () => context.push(AppRoutes.create),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.edit_outlined, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Tulis sesuatu...',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
