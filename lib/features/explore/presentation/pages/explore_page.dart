import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/post_card.dart';

/// Explore — subject list + topic filter + filtered posts.
class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final filter = ref.watch(feedFilterProvider);
    final topicsAsync = filter.subjectId == null ? null : ref.watch(topicsProvider(filter.subjectId));
    final postsAsync = ref.watch(feedPostsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Column(
        children: [
          // Subject chips
          SizedBox(
            height: 56,
            child: subjectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Mata pelajaran tidak tersedia.')),
              data: (subjects) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: filter.subjectId == null,
                    onSelected: (_) {
                      ref.read(feedFilterProvider.notifier).clear();
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ...subjects.map((s) => Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: Text(s.name),
                          selected: filter.subjectId == s.id,
                          onSelected: (_) {
                            ref.read(feedFilterProvider.notifier).setFilter(FeedFilter(subjectId: s.id));
                          },
                        ),
                      )),
                ],
              ),
            ),
          ),
          // Topic chips (only when subject selected)
          if (filter.subjectId != null && topicsAsync != null)
            SizedBox(
              height: 48,
              child: topicsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Center(child: Text('Gagal memuat topik.')),
                data: (topics) => ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  children: [
                    ChoiceChip(
                      label: const Text('Semua Topik'),
                      selected: filter.topicId == null,
                      onSelected: (_) {
                        final current = ref.read(feedFilterProvider);
                        ref.read(feedFilterProvider.notifier).setFilter(FeedFilter(subjectId: current.subjectId));
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ...topics.map((t) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(t.name),
                            selected: filter.topicId == t.id,
                            onSelected: (_) {
                              final current = ref.read(feedFilterProvider);
                              ref.read(feedFilterProvider.notifier).setFilter(FeedFilter(subjectId: current.subjectId, topicId: t.id));
                            },
                          ),
                        )),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          // Filtered posts
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Gagal memuat post.'),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(onPressed: () => ref.invalidate(feedPostsProvider), child: const Text('Coba lagi')),
                  ],
                ),
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(child: Text('Tidak ada post untuk filter ini.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(feedPostsProvider),
                  child: ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, i) => PostCard(post: posts[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
