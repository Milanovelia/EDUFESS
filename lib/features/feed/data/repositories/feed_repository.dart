import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../models/subject.dart';
import '../models/topic.dart';

/// Data access for social foundation (subjects, topics, posts).
///
/// All reads go through privacy-safe paths:
/// - subjects/topics: direct table (public, no sensitive data)
/// - posts: `posts_feed` view which returns `display_author` already
///   resolved server-side (never exposes real pseudonym for pseudonymous).
class FeedRepository {
  FeedRepository(this._client);

  final SupabaseClient _client;

  // --------------------------------------------------------------------------
  // Subjects / Topics
  // --------------------------------------------------------------------------

  Future<List<Subject>> fetchSubjects() async {
    final data = await _client
        .from('subjects')
        .select('id, name, slug, created_at')
        .order('name');
    return (data as List).map((e) => Subject.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<Topic>> fetchTopics({String? subjectId}) async {
    var query = _client.from('topics').select('id, subject_id, name, slug, created_at');
    if (subjectId != null) {
      query = query.eq('subject_id', subjectId);
    }
    final data = await query.order('name');
    return (data as List).map((e) => Topic.fromMap(e as Map<String, dynamic>)).toList();
  }

  // --------------------------------------------------------------------------
  // Posts (via privacy-safe view)
  // --------------------------------------------------------------------------

  Future<List<Post>> fetchPosts({String? subjectId, String? topicId}) async {
    var query = _client.from('posts_feed').select();
    if (subjectId != null) {
      query = query.eq('subject_id', subjectId);
    }
    if (topicId != null) {
      query = query.eq('topic_id', topicId);
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => Post.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Post?> fetchPostById(String id) async {
    final data = await _client.from('posts_feed').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return Post.fromMap(data);
  }

  // --------------------------------------------------------------------------
  // Search — privacy-safe RPC (M4)
  // --------------------------------------------------------------------------

  /// Privacy-safe search via `search_posts` RPC.
  ///
  /// Returns display_author already resolved server-side.
  /// Filters are optional and combine with AND.
  Future<List<Post>> searchPosts({
    String? query,
    String? subjectId,
    String? topicId,
    String? postType,
    String sort = 'terbaru',
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await _client.rpc('search_posts', params: {
      'p_query': query,
      'p_subject_id': subjectId,
      'p_topic_id': topicId,
      'p_post_type': postType,
      'p_sort': sort,
      'p_limit': limit,
      'p_offset': offset,
    });
    final list = data as List;
    return list.map((e) => Post.fromMap(e as Map<String, dynamic>)).toList();
  }

  // --------------------------------------------------------------------------
  // Create post (writes to base table; RLS + trigger enforce author/alias)
  // --------------------------------------------------------------------------

  Future<void> createPost({
    required String type,
    required String title,
    required String content,
    String? subjectId,
    String? topicId,
    required bool isPseudonymous,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const PostException('Harus login untuk membuat post.');

    await _client.from('posts').insert({
      'author_id': user.id,
      'subject_id': subjectId,
      'topic_id': topicId,
      'type': type,
      'title': title,
      'content': content,
      'is_pseudonymous': isPseudonymous,
      // anonymous_alias is generated server-side; don't send it
    });
  }

  Future<void> softDeletePost(String postId) async {
    await _client.from('posts').update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', postId);
  }

  // --------------------------------------------------------------------------
  // Comments (via privacy-safe view)
  // --------------------------------------------------------------------------

  Future<List<Comment>> fetchComments(String postId) async {
    final data = await _client.from('comments_feed').select().eq('post_id', postId).order('created_at', ascending: true);
    return (data as List).map((e) => Comment.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> createComment({
    required String postId,
    String? parentId,
    required String content,
    required bool isPseudonymous,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const PostException('Harus login untuk berkomentar.');
    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': user.id,
      'parent_id': parentId,
      'content': content,
      'is_pseudonymous': isPseudonymous,
    });
  }

  Future<void> softDeleteComment(String commentId) async {
    await _client.from('comments').update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', commentId);
  }

  // --------------------------------------------------------------------------
  // Helpful
  // --------------------------------------------------------------------------

  Future<void> toggleHelpful(String postId, bool currentlyHelpful) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const PostException('Harus login.');
    if (currentlyHelpful) {
      await _client.from('post_helpful').delete().eq('post_id', postId).eq('user_id', user.id);
    } else {
      await _client.from('post_helpful').insert({'post_id': postId, 'user_id': user.id});
    }
  }

  // --------------------------------------------------------------------------
  // Bookmarks
  // --------------------------------------------------------------------------

  Future<void> toggleBookmark(String postId, bool currentlyBookmarked) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const PostException('Harus login.');
    if (currentlyBookmarked) {
      await _client.from('bookmarks').delete().eq('post_id', postId).eq('user_id', user.id);
    } else {
      await _client.from('bookmarks').insert({'post_id': postId, 'user_id': user.id});
    }
  }

  Future<List<Post>> fetchBookmarkedPosts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final data = await _client
        .from('bookmarks')
        .select('post_id, posts_feed!inner(*)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    // bookmarks returns joined posts_feed; extract inner
    final list = data as List;
    return list.map((e) {
      final inner = (e as Map<String, dynamic>)['posts_feed'] as Map<String, dynamic>;
      return Post.fromMap(inner);
    }).toList();
  }

  // Fallback when inner join not supported: query posts_feed where id in bookmarked ids
  Future<List<Post>> fetchBookmarkedPostsFallback() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final bookmarkRows = await _client.from('bookmarks').select('post_id').eq('user_id', user.id);
    final ids = (bookmarkRows as List).map((e) => (e as Map<String, dynamic>)['post_id'] as String).toList();
    if (ids.isEmpty) return [];
    final data = await _client.from('posts_feed').select().inFilter('id', ids);
    final posts = (data as List).map((e) => Post.fromMap(e as Map<String, dynamic>)).toList();
    // preserve bookmark order desc by created_at of bookmark; sort by created_at desc as approximation
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return posts;
  }

  Future<void> markBestAnswer({required String commentId, required bool isBest}) async {
    await _client.from('comments').update({'is_best_answer': isBest}).eq('id', commentId);
  }
}

/// User-facing post errors (no raw PG messages).
class PostException implements Exception {
  const PostException(this.message);
  final String message;
  @override
  String toString() => 'PostException: $message';
}

/// Maps Supabase/Postgres errors to user-friendly messages.
String translatePostError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('topic does not belong')) {
    return 'Topik tidak sesuai dengan mata pelajaran.';
  }
  if (msg.contains('not authenticated')) {
    return 'Harus login untuk membuat post.';
  }
  if (msg.contains('too long') || msg.contains('too short') || msg.contains('check')) {
    return 'Data post tidak valid. Periksa judul dan konten.';
  }
  if (msg.contains('replies only allowed one level')) {
    return 'Balasan hanya satu level.';
  }
  if (msg.contains('only question posts can have best answer')) {
    return 'Hanya post pertanyaan yang bisa memiliki jawaban terbaik.';
  }
  if (msg.contains('only post author can mark best answer')) {
    return 'Hanya pemilik post yang bisa menandai jawaban terbaik.';
  }
  if (msg.contains('post has been deleted')) {
    return 'Post sudah dihapus.';
  }
  return 'Post gagal dibuat. Coba lagi.';
}

String translateCommentError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('replies only allowed one level')) return 'Balasan hanya satu level.';
  if (msg.contains('parent comment does not belong')) return 'Komentar induk tidak sesuai.';
  if (msg.contains('parent comment has been deleted')) return 'Komentar induk sudah dihapus.';
  if (msg.contains('post has been deleted')) return 'Post sudah dihapus.';
  if (msg.contains('not authenticated')) return 'Harus login untuk berkomentar.';
  if (msg.contains('too long') || msg.contains('check')) return 'Komentar tidak valid.';
  return 'Komentar gagal dikirim.';
}

String translateHelpfulError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('duplicate') || msg.contains('unique') || msg.contains('already exists')) {
    return 'Sudah memberi Helpful.';
  }
  if (msg.contains('post has been deleted')) return 'Post sudah dihapus.';
  return 'Gagal memperbarui Helpful.';
}

String translateBookmarkError(Object error) {
  if (error.toString().toLowerCase().contains('post has been deleted')) return 'Post sudah dihapus.';
  return 'Gagal menyimpan postingan.';
}

String translateBestAnswerError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('only post author can mark')) return 'Hanya pemilik pertanyaan yang bisa menandai jawaban terbaik.';
  if (msg.contains('only question posts')) return 'Hanya post pertanyaan yang bisa memiliki jawaban terbaik.';
  if (msg.contains('deleted comment')) return 'Komentar sudah dihapus.';
  if (msg.contains('duplicate') || msg.contains('unique')) return 'Sudah ada jawaban terbaik untuk post ini.';
  if (msg.contains('comment from other post') || msg.contains('does not belong')) return 'Komentar tidak sesuai dengan post.';
  return 'Jawaban terbaik gagal diperbarui.';
}

String translateSearchError(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('not authenticated')) return 'Harus login untuk mencari.';
  if (msg.contains('invalid post type')) return 'Tipe post tidak valid.';
  return 'Pencarian gagal. Coba lagi.';
}
