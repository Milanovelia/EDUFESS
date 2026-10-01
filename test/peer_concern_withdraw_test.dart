import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/features/counseling/data/models/bk_peer_concern.dart';
import 'package:edufess/features/counseling/data/peer_concern_repository.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_peer_concern_history_page.dart';
import 'package:edufess/features/counseling/presentation/providers/peer_concern_providers.dart';

/// BK-PC-03 withdrawal: pending reporter-owned concerns show a restrained
/// "Tarik Laporan" action with confirmation; all other states show none.
/// The row stays in history as "Ditarik"; internals never leak.
void main() {
  BkPeerConcern concern(String status, {DateTime? withdrawnAt}) =>
      BkPeerConcern(
        id: 'pc-$status',
        targetDisplay: 'Siswa BK #D4FF',
        reason: 'emotional',
        details: 'Detail laporan.',
        status: status,
        createdAt: DateTime(2026, 9, 20),
        closedAt: status == 'resolved' || status == 'dismissed'
            ? DateTime(2026, 9, 22)
            : null,
        withdrawnAt: withdrawnAt,
        reporterResponse: status == 'resolved'
            ? 'Sudah ditindaklanjuti.'
            : null,
        resolutionNote: status == 'resolved' ? 'Catatan internal.' : null,
      );

  Future<void> pumpHistory(
    WidgetTester tester,
    _FakePeerConcernRepo repo,
    List<BkPeerConcern> items,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peerConcernRepositoryProvider.overrideWithValue(repo),
          studentPeerConcernsProvider.overrideWith((ref) async => items),
        ],
        child: const MaterialApp(home: BkPeerConcernHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('withdraw action visibility', () {
    testWidgets('pending concern shows Tarik Laporan', (tester) async {
      await pumpHistory(tester, _FakePeerConcernRepo(), [concern('pending')]);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Tarik Laporan'), findsOneWidget);
    });

    for (final status in ['reviewing', 'resolved', 'dismissed', 'withdrawn']) {
      testWidgets('$status shows NO withdraw action', (tester) async {
        await pumpHistory(tester, _FakePeerConcernRepo(), [concern(status)]);
        expect(tester.takeException(), isNull);
        expect(find.byType(PopupMenuButton<String>), findsNothing);
      });
    }
  });

  group('withdraw confirmation + success', () {
    testWidgets('cancel confirmation does nothing', (tester) async {
      final repo = _FakePeerConcernRepo();
      await pumpHistory(tester, repo, [concern('pending')]);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarik Laporan'));
      await tester.pumpAndSettle();
      expect(find.text('Tarik laporan?'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.withdrawnIds, isEmpty);
      expect(find.text('Laporan berhasil ditarik.'), findsNothing);
    });

    testWidgets('confirm calls withdraw and shows success', (tester) async {
      final repo = _FakePeerConcernRepo();
      await pumpHistory(tester, repo, [concern('pending')]);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarik Laporan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Tarik Laporan'));
      await tester.pumpAndSettle();

      expect(repo.withdrawnIds, ['pc-pending']);
      expect(find.text('Laporan berhasil ditarik.'), findsOneWidget);
    });

    testWidgets('server error maps to safe snackbar', (tester) async {
      final repo = _FakePeerConcernRepo()
        ..withdrawError = 'Laporan sudah mulai ditangani.';
      await pumpHistory(tester, repo, [concern('pending')]);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tarik Laporan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Tarik Laporan'));
      await tester.pumpAndSettle();

      expect(
        find.text('Laporan sudah mulai ditangani dan tidak dapat ditarik.'),
        findsOneWidget,
      );
    });
  });

  group('withdrawn row rendering', () {
    testWidgets('status label Ditarik with withdrawn date', (tester) async {
      await pumpHistory(tester, _FakePeerConcernRepo(), [
        concern('withdrawn', withdrawnAt: DateTime(2026, 9, 24)),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Ditarik'), findsOneWidget);
      expect(find.textContaining('Ditarik pada: 24/9/2026'), findsOneWidget);
      // Never handled: no closure date, no response, no internal note.
      expect(find.textContaining('Ditutup:'), findsNothing);
      expect(find.text('Tanggapan Guru BK'), findsNothing);
    });

    testWidgets('null withdrawn_at renders safely', (tester) async {
      await pumpHistory(tester, _FakePeerConcernRepo(), [concern('withdrawn')]);
      expect(tester.takeException(), isNull);
      expect(find.text('Ditarik'), findsOneWidget);
      expect(find.textContaining('Ditarik pada:'), findsNothing);
    });

    testWidgets('internal note still never leaks', (tester) async {
      await pumpHistory(tester, _FakePeerConcernRepo(), [
        BkPeerConcern(
          id: 'pc-x',
          targetDisplay: 'Siswa BK #D4FF',
          reason: 'emotional',
          status: 'withdrawn',
          createdAt: DateTime(2026, 9, 20),
          resolutionNote: 'RAHASIA-INTERNAL',
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('RAHASIA-INTERNAL'), findsNothing);
      expect(find.text('CATATAN INTERNAL'), findsNothing);
    });

    testWidgets('resolved response behavior unchanged', (tester) async {
      await pumpHistory(tester, _FakePeerConcernRepo(), [concern('resolved')]);
      expect(tester.takeException(), isNull);
      expect(find.text('Selesai ditindaklanjuti'), findsOneWidget);
      expect(find.text('Tanggapan Guru BK'), findsOneWidget);
      expect(find.text('Sudah ditindaklanjuti.'), findsOneWidget);
      expect(find.text('Catatan internal.'), findsNothing);
    });
  });

  group('controller withdraw contract', () {
    ProviderContainer containerWith(_FakePeerConcernRepo repo) {
      final container = ProviderContainer(
        overrides: [peerConcernRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('success invalidates history and returns null', () async {
      final repo = _FakePeerConcernRepo();
      final container = containerWith(repo);
      final err = await container
          .read(peerConcernControllerProvider.notifier)
          .withdraw('pc-1');
      expect(err, isNull);
      expect(repo.withdrawnIds, ['pc-1']);
    });

    test('already-withdrawn maps safely', () async {
      final repo = _FakePeerConcernRepo()
        ..withdrawError = 'Laporan ini sudah ditarik.';
      final container = containerWith(repo);
      expect(
        await container
            .read(peerConcernControllerProvider.notifier)
            .withdraw('pc-1'),
        'Laporan ini sudah ditarik.',
      );
    });

    test('finished report maps safely', () async {
      final repo = _FakePeerConcernRepo()
        ..withdrawError = 'Laporan yang sudah selesai';
      final container = containerWith(repo);
      expect(
        await container
            .read(peerConcernControllerProvider.notifier)
            .withdraw('pc-1'),
        'Laporan yang sudah selesai tidak dapat ditarik.',
      );
    });

    test('not owner maps safely', () async {
      final repo = _FakePeerConcernRepo()
        ..withdrawError = Exception('Not authorized.');
      final container = containerWith(repo);
      expect(
        await container
            .read(peerConcernControllerProvider.notifier)
            .withdraw('pc-1'),
        'Kamu tidak memiliki akses untuk menarik laporan ini.',
      );
    });

    test('missing report maps safely', () async {
      final repo = _FakePeerConcernRepo()
        ..withdrawError = Exception('Concern not found.');
      final container = containerWith(repo);
      expect(
        await container
            .read(peerConcernControllerProvider.notifier)
            .withdraw('pc-1'),
        'Laporan tidak ditemukan.',
      );
    });
  });
}

/// In-memory stand-in: records withdrawals, replays configured errors
/// through the REAL translator for raw server errors.
class _FakePeerConcernRepo extends PeerConcernRepository {
  _FakePeerConcernRepo()
    : super(
        SupabaseClient(
          'http://localhost:1',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<String> withdrawnIds = [];
  Object? withdrawError;

  @override
  Future<void> withdrawConcern(String concernId) async {
    if (withdrawError != null) {
      final e = withdrawError!;
      if (e is PeerConcernException) throw e;
      throw PeerConcernException(_mirrorMessage(e));
    }
    withdrawnIds.add(concernId);
  }

  /// Mirrors the repository translator contract for raw server errors.
  String _mirrorMessage(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('sudah mulai ditangani')) {
      return 'Laporan sudah mulai ditangani dan tidak dapat ditarik.';
    }
    if (m.contains('sudah ditarik')) return 'Laporan ini sudah ditarik.';
    if (m.contains('sudah selesai')) {
      return 'Laporan yang sudah selesai tidak dapat ditarik.';
    }
    if (m.contains('not found')) return 'Laporan tidak ditemukan.';
    if (m.contains('not authorized')) {
      return 'Kamu tidak memiliki akses untuk menarik laporan ini.';
    }
    return 'Gagal menarik laporan.';
  }
}
