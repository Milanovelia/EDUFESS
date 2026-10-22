import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/counseling_repository.dart';
import '../../data/models/bk_appointment.dart';
import '../../data/models/bk_conversation.dart';
import '../../data/models/bk_mood_checkin.dart';

final counselingRepositoryProvider = Provider<CounselingRepository>((ref) {
  return CounselingRepository(ref.watch(supabaseClientProvider));
});

final hasBkConsentProvider = FutureProvider.autoDispose<bool>((ref) async {
  return ref.watch(counselingRepositoryProvider).hasActiveConsent();
});

final studentConversationsProvider =
    FutureProvider.autoDispose<List<BkConversation>>((ref) async {
      return ref
          .watch(counselingRepositoryProvider)
          .fetchStudentConversations();
    });

final counselorQueueProvider = FutureProvider.autoDispose<List<BkConversation>>(
  (ref) async {
    return ref.watch(counselingRepositoryProvider).fetchCounselorQueue();
  },
);

final counselorAssignedProvider =
    FutureProvider.autoDispose<List<BkConversation>>((ref) async {
      return ref.watch(counselingRepositoryProvider).fetchCounselorAssigned();
    });

final counselingMessagesProvider = FutureProvider.family
    .autoDispose<List<BkMessage>, String>((ref, conversationId) async {
      return ref
          .watch(counselingRepositoryProvider)
          .fetchMessages(conversationId);
    });

final studentMoodHistoryProvider =
    FutureProvider.autoDispose<List<BkMoodCheckin>>((ref) async {
      return ref
          .watch(counselingRepositoryProvider)
          .fetchStudentMoodHistory(limit: 30, offset: 0);
    });

final counselorMoodHistoryProvider = FutureProvider.family
    .autoDispose<List<BkMoodCheckin>, String>((ref, conversationId) async {
      return ref
          .watch(counselingRepositoryProvider)
          .fetchCounselorStudentMoodHistory(
            conversationId: conversationId,
            limit: 30,
            offset: 0,
          );
    });

final availableSlotsProvider = FutureProvider.autoDispose<List<CounselorSlot>>((
  ref,
) async {
  return ref.watch(counselingRepositoryProvider).fetchAvailableSlots();
});

final studentAppointmentsProvider =
    FutureProvider.autoDispose<List<BkAppointment>>((ref) async {
      return ref.watch(counselingRepositoryProvider).fetchStudentAppointments();
    });

final counselorAppointmentsProvider =
    FutureProvider.autoDispose<List<BkAppointment>>((ref) async {
      return ref
          .watch(counselingRepositoryProvider)
          .fetchCounselorAppointments();
    });

final myAvailabilityProvider =
    FutureProvider.autoDispose<List<CounselorAvailability>>((ref) async {
      return ref.watch(counselingRepositoryProvider).fetchMyAvailability();
    });

final bkConversationProvider = FutureProvider.family
    .autoDispose<BkConversation?, String>((ref, id) async {
      // P0-3: resolve from role-appropriate RPC lists only. RPC failures
      // propagate as typed errors (AsyncError); never swallowed to null,
      // never replaced by a direct full-row select.
      final repo = ref.watch(counselingRepositoryProvider);
      final profile = await ref.watch(currentProfileProvider.future);
      if (profile == null) {
        throw const CounselingException('Harus login.');
      }
      if (profile.isStudent) {
        for (final c in await repo.fetchStudentConversations()) {
          if (c.id == id) return c;
        }
      } else if (profile.isCounselor) {
        for (final c in await repo.fetchCounselorQueue()) {
          if (c.id == id) return c;
        }
        for (final c in await repo.fetchCounselorAssigned()) {
          if (c.id == id) return c;
        }
      } else {
        throw const CounselingException('Tidak memiliki akses.');
      }
      // Not found in any list the caller may see: legitimate null
      // (denied/nonexistent), distinct from a thrown RPC error above.
      return null;
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
      final msg = e is CounselingException
          ? e.message
          : 'Gagal menyimpan persetujuan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> createConversation() async {
    state = const AsyncLoading();
    try {
      final id = await ref
          .read(counselingRepositoryProvider)
          .createConversation();
      ref.invalidate(studentConversationsProvider);
      ref.invalidate(counselorQueueProvider);
      state = const AsyncData(null);
      return id;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal membuat percakapan.';
      state = AsyncError(msg, StackTrace.current);
      return null;
    }
  }

  Future<String?> claim(String conversationId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .claimConversation(conversationId);
      ref.invalidate(counselorQueueProvider);
      ref.invalidate(counselorAssignedProvider);
      ref.invalidate(studentConversationsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal mengklaim percakapan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .sendMessage(conversationId: conversationId, content: content);
      ref.invalidate(counselingMessagesProvider(conversationId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Pesan gagal dikirim.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  /// Soft-delete the caller's own counseling message and refresh the list.
  Future<String?> deleteMessage({
    required String messageId,
    required String conversationId,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .deleteMessage(messageId);
      ref.invalidate(counselingMessagesProvider(conversationId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal menghapus pesan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<({String studentId, String pseudonym})?> reveal({
    required String conversationId,
    required String reason,
  }) async {
    state = const AsyncLoading();
    try {
      final res = await ref
          .read(counselingRepositoryProvider)
          .revealIdentity(conversationId: conversationId, reason: reason);
      state = const AsyncData(null);
      return res;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Akses identitas gagal.';
      state = AsyncError(msg, StackTrace.current);
      return null;
    }
  }

  Future<String?> close(String conversationId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .closeConversation(conversationId);
      ref.invalidate(counselorAssignedProvider);
      ref.invalidate(counselorQueueProvider);
      ref.invalidate(studentConversationsProvider);
      ref.invalidate(bkConversationProvider(conversationId));
      ref.invalidate(counselingMessagesProvider(conversationId));
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal menyelesaikan percakapan.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> createAvailability({
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    state = const AsyncLoading();
    try {
      final id = await ref
          .read(counselingRepositoryProvider)
          .createAvailability(
            date: date,
            startTime: startTime,
            endTime: endTime,
          );
      ref.invalidate(myAvailabilityProvider);
      ref.invalidate(availableSlotsProvider);
      state = const AsyncData(null);
      return id;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal membuat slot.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> updateAvailability({
    required String availabilityId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(counselingRepositoryProvider).updateAvailability(availabilityId: availabilityId, date: date, startTime: startTime, endTime: endTime);
      ref.invalidate(myAvailabilityProvider);
      ref.invalidate(availableSlotsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal mengubah slot.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> deactivateAvailability(String availabilityId) async {
    state = const AsyncLoading();
    try {
      await ref.read(counselingRepositoryProvider).deactivateAvailability(availabilityId: availabilityId);
      ref.invalidate(myAvailabilityProvider);
      ref.invalidate(availableSlotsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal menonaktifkan slot.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> requestAppointment({
    required String availabilityId,
    String? studentNote,
    String? conversationId,
  }) async {
    state = const AsyncLoading();
    try {
      final id = await ref
          .read(counselingRepositoryProvider)
          .requestAppointment(
            availabilityId: availabilityId,
            studentNote: studentNote,
            conversationId: conversationId,
          );
      ref.invalidate(studentAppointmentsProvider);
      ref.invalidate(counselorAppointmentsProvider);
      ref.invalidate(availableSlotsProvider);
      state = const AsyncData(null);
      return id;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal membuat janji.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> acceptAppointment(String appointmentId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .acceptAppointment(appointmentId);
      ref.invalidate(counselorAppointmentsProvider);
      ref.invalidate(studentAppointmentsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal menerima janji.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> rejectAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .rejectAppointment(appointmentId, reason: reason);
      ref.invalidate(counselorAppointmentsProvider);
      ref.invalidate(studentAppointmentsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal menolak janji.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> rescheduleAppointment({
    required String appointmentId,
    required DateTime newStart,
    required DateTime newEnd,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .rescheduleAppointment(
            appointmentId: appointmentId,
            newStart: newStart,
            newEnd: newEnd,
          );
      ref.invalidate(counselorAppointmentsProvider);
      ref.invalidate(studentAppointmentsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal mengatur ulang janji.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> cancelStudentAppointment(String appointmentId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .cancelStudentAppointment(appointmentId);
      ref.invalidate(studentAppointmentsProvider);
      ref.invalidate(counselorAppointmentsProvider);
      ref.invalidate(availableSlotsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal membatalkan janji.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> cancelCounselorAppointment(
    String appointmentId, {
    String? reason,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .cancelCounselorAppointment(appointmentId, reason: reason);
      ref.invalidate(counselorAppointmentsProvider);
      ref.invalidate(studentAppointmentsProvider);
      ref.invalidate(availableSlotsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal membatalkan janji.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> completeAppointment(String appointmentId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .completeAppointment(appointmentId);
      ref.invalidate(counselorAppointmentsProvider);
      ref.invalidate(studentAppointmentsProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal menyelesaikan janji.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

class MoodController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> submit({required int moodLevel, String? note}) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(counselingRepositoryProvider)
          .submitMoodCheckin(moodLevel: moodLevel, note: note);
      ref.invalidate(studentMoodHistoryProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException
          ? e.message
          : 'Gagal menyimpan mood.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> deleteMoodCheckin(String checkinId) async {
    state = const AsyncLoading();
    try {
      await ref.read(counselingRepositoryProvider).deleteMoodCheckin(checkinId);
      ref.invalidate(studentMoodHistoryProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is CounselingException ? e.message : 'Gagal menghapus check-in.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

final moodControllerProvider =
    NotifierProvider<MoodController, AsyncValue<void>>(MoodController.new);

final counselingControllerProvider =
    NotifierProvider<CounselingController, AsyncValue<void>>(
      CounselingController.new,
    );
