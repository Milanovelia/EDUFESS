import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/moderation_repository.dart';
import '../../data/models/moderation_report.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(supabaseClientProvider));
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final p = await ref.watch(currentProfileProvider.future);
  return p?.isAdmin ?? false;
});

final moderationQueueProvider = FutureProvider<List<ModerationReport>>((ref) async {
  return ref.watch(moderationRepositoryProvider).fetchQueue();
});

class ReportController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> reportPost({required String postId, required String reason, String? details}) async {
    state = const AsyncLoading();
    try {
      await ref.read(moderationRepositoryProvider).reportContent(
            targetType: 'post',
            postId: postId,
            reason: reason,
            details: details,
          );
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is ReportException ? e.message : 'Laporan gagal dikirim.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> reportComment({required String commentId, required String reason, String? details}) async {
    state = const AsyncLoading();
    try {
      await ref.read(moderationRepositoryProvider).reportContent(
            targetType: 'comment',
            commentId: commentId,
            reason: reason,
            details: details,
          );
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is ReportException ? e.message : 'Laporan gagal dikirim.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

final reportControllerProvider = NotifierProvider<ReportController, AsyncValue<void>>(ReportController.new);

class ModerationActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> dismiss(String reportId) async {
    state = const AsyncLoading();
    try {
      await ref.read(moderationRepositoryProvider).moderateReport(reportId: reportId, action: 'dismiss_report');
      ref.invalidate(moderationQueueProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is ReportException ? e.message : 'Tindakan moderasi gagal.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> remove(String reportId) async {
    state = const AsyncLoading();
    try {
      await ref.read(moderationRepositoryProvider).moderateReport(reportId: reportId, action: 'remove_content');
      ref.invalidate(moderationQueueProvider);
      state = const AsyncData(null);
      return null;
    } catch (e) {
      final msg = e is ReportException ? e.message : 'Tindakan moderasi gagal.';
      state = AsyncError(msg, StackTrace.current);
      return msg;
    }
  }
}

final moderationActionProvider = NotifierProvider<ModerationActionController, AsyncValue<void>>(ModerationActionController.new);
