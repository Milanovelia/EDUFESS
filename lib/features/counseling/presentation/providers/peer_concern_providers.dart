import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../data/peer_concern_repository.dart';
import '../../data/models/bk_peer_concern.dart';

final peerConcernRepositoryProvider = Provider<PeerConcernRepository>((ref) {
  return PeerConcernRepository(ref.watch(supabaseClientProvider));
});

final peerSearchProvider = FutureProvider.family
    .autoDispose<List<PeerStudent>, String>((ref, query) async {
      if (query.trim().length < 2) return [];
      return ref
          .watch(peerConcernRepositoryProvider)
          .searchPeers(query, limit: 10);
    });

final studentPeerConcernsProvider =
    FutureProvider.autoDispose<List<BkPeerConcern>>((ref) async {
      return ref.watch(peerConcernRepositoryProvider).fetchStudentHistory();
    });

final counselorPeerConcernQueueProvider =
    FutureProvider.autoDispose<List<BkPeerConcern>>((ref) async {
      return ref.watch(peerConcernRepositoryProvider).fetchCounselorQueue();
    });

final counselorPeerConcernHistoryProvider =
    FutureProvider.autoDispose<List<BkPeerConcern>>((ref) async {
      return ref.watch(peerConcernRepositoryProvider).fetchCounselorHistory();
    });

final peerConcernDetailProvider = FutureProvider.family
    .autoDispose<BkPeerConcern, String>((ref, id) async {
      return ref.watch(peerConcernRepositoryProvider).fetchDetail(id);
    });

class PeerConcernController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> submit({
    required String targetRef,
    required String reason,
    String? details,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(peerConcernRepositoryProvider)
          .submit(
            targetStudentRef: targetRef,
            reason: reason,
            details: details,
          );
      ref.invalidate(studentPeerConcernsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is PeerConcernException
          ? e.message
          : 'Gagal mengirim kepedulian.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> claim(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(peerConcernRepositoryProvider).claim(id);
      ref.invalidate(counselorPeerConcernQueueProvider);
      ref.invalidate(counselorPeerConcernHistoryProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is PeerConcernException ? e.message : 'Gagal mengklaim.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> resolve(String id, {String? note, String? response}) async {
    state = const AsyncLoading();
    try {
      await ref.read(peerConcernRepositoryProvider).resolve(id, note: note, response: response);
      ref.invalidate(counselorPeerConcernQueueProvider);
      ref.invalidate(counselorPeerConcernHistoryProvider);
      ref.invalidate(peerConcernDetailProvider(id));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is PeerConcernException
          ? e.message
          : 'Gagal menyelesaikan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> dismiss(String id, {String? note, String? response}) async {
    state = const AsyncLoading();
    try {
      await ref.read(peerConcernRepositoryProvider).dismiss(id, note: note, response: response);
      ref.invalidate(counselorPeerConcernQueueProvider);
      ref.invalidate(counselorPeerConcernHistoryProvider);
      ref.invalidate(peerConcernDetailProvider(id));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is PeerConcernException ? e.message : 'Gagal menutup.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> withdraw(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(peerConcernRepositoryProvider).withdrawConcern(id);
      ref.invalidate(studentPeerConcernsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is PeerConcernException ? e.message : 'Gagal menarik laporan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

final peerConcernControllerProvider =
    NotifierProvider<PeerConcernController, AsyncValue<void>>(
      PeerConcernController.new,
    );
