import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../data/counseling_repository.dart';
import '../../data/models/bk_conversation.dart';

final counselingRepositoryProvider = Provider<CounselingRepository>((ref) {
  return CounselingRepository(ref.watch(supabaseClientProvider));
});

final hasBkConsentProvider = FutureProvider<bool>((ref) async {
  return ref.watch(counselingRepositoryProvider).hasActiveConsent();
});

final studentConversationsProvider = FutureProvider<List<BkConversation>>((ref) async {
  return ref.watch(counselingRepositoryProvider).fetchStudentConversations();
});

final counselorQueueProvider = FutureProvider<List<BkConversation>>((ref) async {
  return ref.watch(counselingRepositoryProvider).fetchCounselorQueue();
});

final counselorAssignedProvider = FutureProvider<List<BkConversation>>((ref) async {
  return ref.watch(counselingRepositoryProvider).fetchCounselorAssigned();
});

final counselingMessagesProvider = FutureProvider.family<List<BkMessage>, String>((ref, conversationId) async {
  return ref.watch(counselingRepositoryProvider).fetchMessages(conversationId);
});

final bkConversationProvider = FutureProvider.family<BkConversation?, String>((ref, id) async {
  final repo = ref.watch(counselingRepositoryProvider);
  // Try student list first, then counselor, then direct fetch
  try {
    final list = await repo.fetchStudentConversations();
    for (final c in list) {
      if (c.id == id) return c;
    }
  } catch (_) {}
  try {
    final queue = await repo.fetchCounselorQueue();
    for (final c in queue) {
      if (c.id == id) return c;
    }
  } catch (_) {}
  try {
    final assigned = await repo.fetchCounselorAssigned();
    for (final c in assigned) {
      if (c.id == id) return c;
    }
  } catch (_) {}
  // Fallback direct (participant can select own via RLS)
  final client = ref.watch(supabaseClientProvider);
  final data = await client.from('counseling_conversations').select().eq('id', id).maybeSingle();
  if (data == null) return null;
  return BkConversation.fromMap(data);
});

class CounselingController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> createConsent() async {
    state = const AsyncLoading();
    try {
      await ref.read(counselingRepositoryProvider).createConsent();
      ref.invalidate(hasBkConsentProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal menyimpan persetujuan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> createConversation() async {
    state = const AsyncLoading();
    try {
      final id = await ref.read(counselingRepositoryProvider).createConversation();
      ref.invalidate(studentConversationsProvider);
      ref.invalidate(counselorQueueProvider);
      state = const AsyncData(null);
      return id;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal membuat percakapan.';
      state = AsyncError(msg, StackTrace.current);
      return null;
    }
  }

  Future<String?> claim(String conversationId) async {
    state = const AsyncLoading();
    try {
      await ref.read(counselingRepositoryProvider).claimConversation(conversationId);
      ref.invalidate(counselorQueueProvider);
      ref.invalidate(counselorAssignedProvider);
      ref.invalidate(studentConversationsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal mengklaim percakapan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> sendMessage({required String conversationId, required String content}) async {
    state = const AsyncLoading();
    try {
      await ref.read(counselingRepositoryProvider).sendMessage(conversationId: conversationId, content: content);
      ref.invalidate(counselingMessagesProvider(conversationId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Pesan gagal dikirim.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<({String studentId, String pseudonym})?> reveal({required String conversationId, required String reason}) async {
    state = const AsyncLoading();
    try {
      final res = await ref.read(counselingRepositoryProvider).revealIdentity(conversationId: conversationId, reason: reason);
      state = const AsyncData(null);
      return res;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Akses identitas gagal.';
      state = AsyncError(msg, StackTrace.current);
      return null;
    }
  }

  Future<String?> close(String conversationId) async {
    state = const AsyncLoading();
    try {
      await ref.read(counselingRepositoryProvider).closeConversation(conversationId);
      ref.invalidate(counselorAssignedProvider);
      ref.invalidate(counselorQueueProvider);
      ref.invalidate(studentConversationsProvider);
      ref.invalidate(bkConversationProvider(conversationId));
      ref.invalidate(counselingMessagesProvider(conversationId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal menyelesaikan percakapan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

final counselingControllerProvider = NotifierProvider<CounselingController, AsyncValue<void>>(CounselingController.new);
