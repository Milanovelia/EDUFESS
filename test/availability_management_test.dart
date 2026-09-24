import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/features/counseling/data/counseling_repository.dart';
import 'package:edufess/features/counseling/data/models/bk_appointment.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_availability_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';

/// BK-APPT-02: counselor availability management (edit + deactivate).
///
/// Server rules live in migration 20260831000018 and are enforced inside
/// the RPCs. Error-contract tests below run the REAL repository
/// translator and REAL controller against raw [PostgrestException]s via
/// [_RpcClient], so the asserted Indonesian messages are the production
/// mapping — not a copy of it. UI tests drive the REAL controller with
/// an in-memory [_RecordingRepo].
/// Live-DB behaviors (cross-counselor denial, discovery exclusion) are
/// verified on device against the deployed database.
void main() {
  ProviderContainer containerWithRepo(CounselingRepository repo) {
    final container = ProviderContainer(
      overrides: [counselingRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  CounselingRepository repoThrowing(String message) =>
      CounselingRepository(_RpcClient(PostgrestException(message: message)));

  Future<String?> updateVia(
    ProviderContainer container, {
    String id = 'slot-1',
    DateTime? date,
    String start = '09:00:00',
    String end = '10:00:00',
  }) => container
      .read(counselingControllerProvider.notifier)
      .updateAvailability(
        availabilityId: id,
        date: date ?? DateTime.now().add(const Duration(days: 2)),
        startTime: start,
        endTime: end,
      );

  group('updateAvailability error contract (real translator)', () {
    test('booked slot explains instead of failing silently', () async {
      final container = containerWithRepo(
        repoThrowing('Slot ini sudah dipesan sehingga tidak bisa diubah.'),
      );
      expect(
        await updateVia(container),
        'Slot ini sudah dipesan sehingga tidak bisa diubah.',
      );
    });

    test('another counselor slot maps to access denial', () async {
      final container = containerWithRepo(repoThrowing('Not authorized.'));
      expect(await updateVia(container), 'Tidak memiliki akses.');
    });

    test('missing slot maps to not found', () async {
      final container = containerWithRepo(
        repoThrowing('Slot tidak ditemukan.'),
      );
      expect(await updateVia(container), 'Slot tidak ditemukan.');
    });

    test('invalid and past server errors map correctly', () async {
      var container = containerWithRepo(repoThrowing('Invalid time.'));
      expect(await updateVia(container), 'Waktu tidak valid.');

      container = containerWithRepo(repoThrowing('Past slot.'));
      expect(await updateVia(container), 'Slot sudah lewat.');

      container = containerWithRepo(repoThrowing('Slot sudah ada.'));
      expect(await updateVia(container), 'Slot sudah ada.');
    });
  });

  group('deactivateAvailability error contract (real translator)', () {
    Future<String?> deactivateVia(ProviderContainer container) => container
        .read(counselingControllerProvider.notifier)
        .deactivateAvailability('slot-1');

    test('deactivate booked slot explains instead of deleting', () async {
      final container = containerWithRepo(
        repoThrowing(
          'Slot ini sudah dipesan sehingga tidak bisa dinonaktifkan.',
        ),
      );
      expect(
        await deactivateVia(container),
        'Slot ini sudah dipesan sehingga tidak bisa dinonaktifkan.',
      );
    });

    test('deactivate another counselor slot maps to access denial', () async {
      final container = containerWithRepo(repoThrowing('Not authorized.'));
      expect(await deactivateVia(container), 'Tidak memiliki akses.');
    });
  });

  group('CounselorAvailabilityPage management UI', () {
    CounselorAvailability slot({
      required String id,
      required DateTime date,
      bool active = true,
    }) => CounselorAvailability(
      id: id,
      counselorId: 'c1',
      availableDate: date,
      startTime: '09:00:00',
      endTime: '10:00:00',
      isActive: active,
    );

    Future<void> pumpPage(
      WidgetTester tester,
      _RecordingRepo repo,
      List<CounselorAvailability> slots,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselingRepositoryProvider.overrideWithValue(repo),
            myAvailabilityProvider.overrideWith((ref) async => slots),
          ],
          child: const MaterialApp(home: CounselorAvailabilityPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('active future slot exposes Edit and Nonaktifkan', (
      tester,
    ) async {
      await pumpPage(tester, _RecordingRepo(), [
        slot(id: 's1', date: DateTime.now().add(const Duration(days: 2))),
      ]);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Nonaktifkan'), findsOneWidget);
    });

    testWidgets('past slot has no management menu (read-only)', (tester) async {
      await pumpPage(tester, _RecordingRepo(), [
        slot(id: 's1', date: DateTime.now().subtract(const Duration(days: 2))),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('inactive slot has no management menu', (tester) async {
      await pumpPage(tester, _RecordingRepo(), [
        slot(
          id: 's1',
          date: DateTime.now().add(const Duration(days: 2)),
          active: false,
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('(nonaktif)'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('Nonaktifkan asks confirmation then deactivates', (
      tester,
    ) async {
      final repo = _RecordingRepo();
      await pumpPage(tester, repo, [
        slot(id: 's1', date: DateTime.now().add(const Duration(days: 2))),
      ]);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nonaktifkan'));
      await tester.pumpAndSettle();
      expect(find.text('Nonaktifkan Slot'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
      await tester.pumpAndSettle();
      expect(repo.deactivatedIds, ['s1']);
      expect(find.text('Slot dinonaktifkan.'), findsOneWidget);
    });

    testWidgets('Edit dialog prefills and saves', (tester) async {
      final repo = _RecordingRepo();
      await pumpPage(tester, repo, [
        slot(id: 's1', date: DateTime.now().add(const Duration(days: 2))),
      ]);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Slot'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(repo.updatedIds, ['s1']);
      expect(repo.updatedStart, '09:00:00');
      expect(find.text('Slot diubah.'), findsOneWidget);
    });

    testWidgets('empty list state remains valid', (tester) async {
      await pumpPage(tester, _RecordingRepo(), []);
      expect(tester.takeException(), isNull);
      expect(find.text('Belum ada slot.'), findsOneWidget);
    });
  });
}

/// Supabase client whose RPCs fail with a raw server-style error, so the
/// REAL repository translator and controller mapping execute.
class _RpcClient extends SupabaseClient {
  _RpcClient(this.rpcError)
    : super(
        'http://localhost:1',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final Object rpcError;

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    get = false,
  }) {
    throw rpcError;
  }
}

/// In-memory stand-in for success-path behavior (records management calls).
class _RecordingRepo extends CounselingRepository {
  _RecordingRepo()
    : super(
        SupabaseClient(
          'http://localhost:1',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final List<String> updatedIds = [];
  final List<String> deactivatedIds = [];
  String? updatedStart;

  @override
  Future<void> updateAvailability({
    required String availabilityId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    updatedIds.add(availabilityId);
    updatedStart = startTime;
  }

  @override
  Future<void> deactivateAvailability({required String availabilityId}) async {
    deactivatedIds.add(availabilityId);
  }
}
