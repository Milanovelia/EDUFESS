import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../feed/data/models/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../providers/explore_search_providers.dart';

/// Explore — upgraded M4: search, filters, sorting, pagination, privacy-safe.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(exploreSearchProvider).query;
    _controller = TextEditingController(text: initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(exploreSearchProvider.notifier).setQuery(v);
    });
  }

  void _onSubmitted(String v) {
    _debounce?.cancel();
    ref.read(exploreSearchProvider.notifier).setQuery(v);
    if (v.trim().isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).add(v);
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(exploreSearchProvider.notifier).clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(exploreSearchProvider);
    final subjectsAsync = ref.watch(subjectsProvider);
    final topicsAsync = ref.watch(topicsProvider(searchState.subjectId));
    final recent = ref.watch(recentSearchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Cari judul, konten, atau topik...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchState.query.isNotEmpty || _controller.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
            ),
          ),

          // Recent searches (session-only, max 5)
          if (searchState.query.isEmpty && recent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Pencarian terbaru', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton(onPressed: () => ref.read(recentSearchesProvider.notifier).clear(), child: const Text('Hapus')),
                    ],
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: recent.map((q) => ActionChip(
                          label: Text(q),
                          onPressed: () {
                            _controller.text = q;
                            ref.read(exploreSearchProvider.notifier).setQuery(q);
                          },
                        )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),

          // Subjects
          SizedBox(
            height: 56,
            child: subjectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Gagal memuat topik.')),
              data: (subjects) {
                if (subjects.isEmpty) {
                  return const Center(child: Text('Belum ada kategori yang tersedia.'));
                }
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  children: [
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: searchState.subjectId == null,
                      onSelected: (_) => ref.read(exploreSearchProvider.notifier).setSubject(null),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ...subjects.map((s) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(s.name),
                            selected: searchState.subjectId == s.id,
                            onSelected: (_) => ref.read(exploreSearchProvider.notifier).setSubject(s.id),
                          ),
                        )),
                  ],
                );
              },
            ),
          ),

          // Topics (filtered by selected subject; when no subject show placeholder)
          SizedBox(
            height: 48,
            child: topicsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Gagal memuat topik.')),
              data: (topics) {
                if (topics.isEmpty) {
                  return const Center(child: Text('Belum ada kategori yang tersedia.'));
                }
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  children: [
                    ChoiceChip(
                      label: const Text('Semua Topik'),
                      selected: searchState.topicId == null,
                      onSelected: (_) => ref.read(exploreSearchProvider.notifier).setTopic(null),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ...topics.map((t) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(t.name),
                            selected: searchState.topicId == t.id,
                            onSelected: (_) => ref.read(exploreSearchProvider.notifier).setTopic(t.id),
                          ),
                        )),
                  ],
                );
              },
            ),
          ),

          // Filters: Post type + Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Semua'),
                          selected: searchState.postType == null,
                          onSelected: (_) => ref.read(exploreSearchProvider.notifier).setPostType(null),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ...PostType.all.map((type) => Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: ChoiceChip(
                                label: Text(PostType.labels[type] ?? type),
                                selected: searchState.postType == type,
                                onSelected: (_) => ref.read(exploreSearchProvider.notifier).setPostType(type),
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                DropdownButton<String>(
                  value: searchState.sort,
                  items: ExploreSort.all
                      .map((s) => DropdownMenuItem(value: s, child: Text(ExploreSort.labels[s]!)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) ref.read(exploreSearchProvider.notifier).setSort(v);
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Results
          Expanded(child: _buildResults(context, searchState)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, ExploreSearchState state) {
    if (state.loading && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: () => ref.read(exploreSearchProvider.notifier).refresh(), child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }
    if (!state.hasQueryOrFilter) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Jelajahi materi dan diskusi dari berbagai pelajaran.', textAlign: TextAlign.center),
        ),
      );
    }
    if (state.results.isEmpty) {
      // Distinguish filtered no results vs plain no results
      final hasFilter = state.subjectId != null || state.topicId != null || state.postType != null;
      final msg = state.query.trim().isNotEmpty || hasFilter ? 'Coba ubah kata kunci atau filter pencarian.' : 'Tidak ada hasil yang cocok.';
      // For plain no results without filter, use "Tidak ada hasil yang cocok."
      // For filtered, suggest changing filter.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(state.query.trim().isNotEmpty || hasFilter ? 'Coba ubah kata kunci atau filter pencarian.' : msg, textAlign: TextAlign.center),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.read(exploreSearchProvider.notifier).refresh(),
      child: ListView.builder(
        itemCount: state.results.length + 1,
        itemBuilder: (context, i) {
          if (i == state.results.length) {
            if (state.hasMore) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    if (state.loading) const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonal(
                      onPressed: state.loading ? null : () => ref.read(exploreSearchProvider.notifier).loadMore(),
                      child: const Text('Muat lebih banyak'),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox(height: AppSpacing.md);
          }
          return PostCard(post: state.results[i]);
        },
      ),
    );
  }
}
