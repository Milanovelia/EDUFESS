import 'package:supabase_flutter/supabase_flutter.dart';

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
  // Create post (writes to base table; RLS + trigger enforce author/alias)
  // --------------------------------------------------------------------------

  Future<void> createPost({
    required String type,
    required String title,
    required String content,
    required String subjectId,
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
  return 'Post gagal dibuat. Coba lagi.';
}
