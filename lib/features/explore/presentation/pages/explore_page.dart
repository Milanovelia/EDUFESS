import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../feed/data/models/post.dart';
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
    setState(_controller.clear);
    FocusScope.of(context).unfocus();
    ref.read(exploreSearchProvider.notifier).clearQuery();
  }

  /// Replays a previous query: fills the field with a valid cursor, records
  /// recency, and runs the search.
  void _applyRecent(String query) {
    _debounce?.cancel();
    setState(() {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    });
    ref.read(exploreSearchProvider.notifier).setQuery(query);
    ref.read(recentSearchesProvider.notifier).add(query);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(exploreSearchProvider);
    final recent = ref.watch(recentSearchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Jelajah',
          style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Cari judul atau konten...',
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
                    runSpacing: AppSpacing.xs,
                    children: recent.map((q) => ActionChip(
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          onPressed: () => _applyRecent(q),
                        )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
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
    final notifier = ref.read(exploreSearchProvider.notifier);

    if (state.loading && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.results.isEmpty) {
      return RefreshableStateView(
        onRefresh: notifier.refresh,
        child: ErrorStateView(
          title: 'Pencarian gagal',
          message: state.error!,
          onRetry: notifier.refresh,
        ),
      );
    }
    if (!state.hasQueryOrFilter) {
      return const EmptyStateView(
        icon: Icons.explore_outlined,
        title: 'Temukan pengetahuan',
        message: 'Jelajahi postingan dan diskusi komunitas.',
      );
    }
    if (state.results.isEmpty) {
      final query = state.query.trim();
      return RefreshableStateView(
        onRefresh: notifier.refresh,
        child: EmptyStateView(
          icon: Icons.search_off,
          title: 'Tidak ada hasil',
          message: query.isNotEmpty
              ? 'Tidak ada hasil untuk "$query". Coba kata kunci lain.'
              : 'Tidak ada hasil dengan filter ini. Coba hapus filter.',
        ),
      );
    }
    return Column(
      children: [
        if (state.loading) const LinearProgressIndicator(minHeight: 2),
        if (state.error != null) _InlineErrorBanner(message: state.error!, onRetry: notifier.refresh),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
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
                            onPressed: state.loading ? null : () => notifier.loadMore(),
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
          ),
        ),
      ],
    );
  }
}

/// Slim error strip shown when a refresh/pagination fails but stale results
/// are still on screen.
class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
