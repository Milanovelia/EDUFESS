import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../../feed/data/models/post.dart';
import '../../../feed/data/repositories/feed_repository.dart';

/// Sort options for Explore search.
abstract final class ExploreSort {
  static const String terbaru = 'terbaru';
  static const String helpful = 'helpful';
  static const String comments = 'comments';

  static const List<String> all = [terbaru, helpful, comments];

  static const Map<String, String> labels = {
    terbaru: 'Terbaru',
    helpful: 'Paling Membantu',
    comments: 'Paling Banyak Dikomentari',
  };
}

/// State for Explore search.
class ExploreSearchState {
  const ExploreSearchState({
    this.query = '',
    this.subjectId,
    this.topicId,
    this.postType,
    this.sort = ExploreSort.terbaru,
    this.results = const [],
    this.loading = false,
    this.error,
    this.hasMore = false,
    this.offset = 0,
  });

  final String query;
  final String? subjectId;
  final String? topicId;
  final String? postType;
  final String sort;
  final List<Post> results;
  final bool loading;
  final String? error;
  final bool hasMore;
  final int offset;

  bool get hasQueryOrFilter =>
      query.trim().isNotEmpty || subjectId != null || topicId != null || postType != null;

  ExploreSearchState copyWith({
    String? query,
    String? subjectId,
    String? topicId,
    String? postType,
    String? sort,
    List<Post>? results,
    bool? loading,
    String? error,
    bool? hasMore,
    int? offset,
    bool clearSubject = false,
    bool clearTopic = false,
    bool clearType = false,
    bool clearError = false,
  }) {
    return ExploreSearchState(
      query: query ?? this.query,
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      topicId: clearTopic ? null : (topicId ?? this.topicId),
      postType: clearType ? null : (postType ?? this.postType),
      sort: sort ?? this.sort,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
    );
  }
}

class ExploreSearchNotifier extends Notifier<ExploreSearchState> {
  @override
  ExploreSearchState build() => const ExploreSearchState();

  int _requestId = 0;
  static const int _pageSize = 20;

  FeedRepository get _repo => FeedRepository(ref.read(supabaseClientProvider));

  Future<void> setQuery(String query) async {
    state = state.copyWith(query: query, offset: 0, clearError: true);
    // Avoid immediate network for empty typing; still trigger search for filter-only case
    await _search(reset: true);
  }

  Future<void> setSubject(String? subjectId) async {
    // When subject changes, clear incompatible topic
    String? newTopic = state.topicId;
    if (subjectId == null) {
      // keep topic? but topic belongs to previous subject, so clear
      if (newTopic != null) newTopic = null;
      state = state.copyWith(clearSubject: true, clearTopic: newTopic == null ? false : false, topicId: newTopic, offset: 0, clearError: true);
      // simpler: clear topic whenever subject cleared
      state = ExploreSearchState(
        query: state.query,
        subjectId: null,
        topicId: null,
        postType: state.postType,
        sort: state.sort,
        results: state.results,
        loading: state.loading,
        error: null,
        hasMore: state.hasMore,
        offset: 0,
      );
    } else {
      // if subject changed, topic must be cleared (compatibility enforced server-side but UI clears)
      state = ExploreSearchState(
        query: state.query,
        subjectId: subjectId,
        topicId: null,
        postType: state.postType,
        sort: state.sort,
        results: state.results,
        loading: false,
        error: null,
        hasMore: state.hasMore,
        offset: 0,
      );
    }
    await _search(reset: true);
  }

  Future<void> setTopic(String? topicId) async {
    if (topicId == null) {
      state = ExploreSearchState(
        query: state.query,
        subjectId: state.subjectId,
        topicId: null,
        postType: state.postType,
        sort: state.sort,
        results: state.results,
        loading: state.loading,
        error: null,
        hasMore: state.hasMore,
        offset: 0,
      );
    } else {
      state = state.copyWith(topicId: topicId, offset: 0, clearError: true);
    }
    await _search(reset: true);
  }

  Future<void> setPostType(String? type) async {
    if (type == null) {
      state = ExploreSearchState(
        query: state.query,
        subjectId: state.subjectId,
        topicId: state.topicId,
        postType: null,
        sort: state.sort,
        results: state.results,
        loading: false,
        error: null,
        hasMore: state.hasMore,
        offset: 0,
      );
    } else {
      state = state.copyWith(postType: type, offset: 0, clearError: true);
    }
    await _search(reset: true);
  }

  Future<void> setSort(String sort) async {
    state = state.copyWith(sort: sort, offset: 0, clearError: true);
    await _search(reset: true);
  }

  Future<void> clearAll() async {
    state = const ExploreSearchState();
    await _search(reset: true);
  }

  Future<void> clearQuery() async {
    state = ExploreSearchState(
      query: '',
      subjectId: state.subjectId,
      topicId: state.topicId,
      postType: state.postType,
      sort: state.sort,
      results: state.results,
      loading: false,
      error: null,
      hasMore: false,
      offset: 0,
    );
    await _search(reset: true);
  }

  Future<void> refresh() async {
    await _search(reset: true);
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _search(reset: false);
  }

  Future<void> _search({required bool reset}) async {
    final queryTrimmed = state.query.trim();
    final hasFilter = state.subjectId != null || state.topicId != null || state.postType != null;
    // Empty query + no filter => show discovery, no network
    if (queryTrimmed.isEmpty && !hasFilter) {
      state = state.copyWith(results: [], loading: false, hasMore: false, offset: 0, clearError: true);
      return;
    }

    final currentReq = ++_requestId;
    if (reset) {
      state = state.copyWith(loading: true, clearError: true, offset: 0);
    } else {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      final offset = reset ? 0 : state.offset;
      final results = await _repo.searchPosts(
        query: queryTrimmed.isEmpty ? null : queryTrimmed,
        subjectId: state.subjectId,
        topicId: state.topicId,
        postType: state.postType,
        sort: state.sort,
        limit: _pageSize,
        offset: offset,
      );
      // Stale check
      if (currentReq != _requestId) return;
      final hasMore = results.length == _pageSize;
      final merged = reset ? results : [...state.results, ...results];
      // Deduplicate by id
      final seen = <String>{};
      final deduped = <Post>[];
      for (final p in merged) {
        if (seen.add(p.id)) deduped.add(p);
      }
      state = state.copyWith(
        results: deduped,
        loading: false,
        hasMore: hasMore,
        offset: reset ? results.length : state.offset + results.length,
        clearError: true,
      );
    } catch (e) {
      if (currentReq != _requestId) return;
      state = state.copyWith(loading: false, error: 'Pencarian gagal. Coba lagi.', hasMore: false);
    }
  }
}

final exploreSearchProvider = NotifierProvider<ExploreSearchNotifier, ExploreSearchState>(ExploreSearchNotifier.new);

/// Simple in-memory recent searches (5 max). No extra dependency.
/// Keeps session-only history; documented tradeoff vs persistent storage.
class RecentSearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  static const int maxItems = 5;

  void add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final existing = [...state];
    existing.remove(trimmed);
    existing.insert(0, trimmed);
    if (existing.length > maxItems) {
      state = existing.sublist(0, maxItems);
    } else {
      state = existing;
    }
  }

  void clear() => state = [];
  void removeAt(int index) {
    final copy = [...state];
    copy.removeAt(index);
    state = copy;
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearchesNotifier, List<String>>(RecentSearchesNotifier.new);
