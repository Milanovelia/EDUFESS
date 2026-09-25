import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:edufess/features/counseling/data/models/bk_peer_concern.dart';
import 'package:edufess/features/counseling/data/peer_concern_repository.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_peer_concern_history_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_peer_concern_detail_page.dart';
import 'package:edufess/features/counseling/presentation/providers/peer_concern_providers.dart';

/// BK-PC-02 closure feedback: distinct final states, closure dates, and
/// strict separation of the internal counselor note from the
/// student-visible response.
void main() {
  BkPeerConcern concern({
    required String status,
    String? response,
    String? note,
    DateTime? closedAt,
  }) => BkPeerConcern(
    id: 'pc-1',
    targetDisplay: 'Siswa BK #D4FF',
    reason: 'emotional',
    details: 'Detail laporan.',
    status: status,
    createdAt: DateTime(2026, 9, 20),
    handledAt: DateTime(2026, 9, 21),
    closedAt: closedAt,
    reporterResponse: response,
    resolutionNote: note,
  );

  group('closure model', () {
    test('resolved and dismissed labels are distinct', () {
      expect(
        concern(status: 'resolved').statusLabel,
        'Selesai ditindaklanjuti',
      );
      expect(
        concern(status: 'dismissed').statusLabel,
        'Ditutup tanpa tindak lanjut',
      );
      expect(
        concern(status: 'resolved').statusLabel,
        isNot(concern(status: 'dismissed').statusLabel),
      );
    });

    test('fromMap parses closure fields, missing keys stay null', () {
      final full = BkPeerConcern.fromMap({
        'concern_id': '1',
        'target_display': 't',
        'reason': 'emotional',
        'status': 'resolved',
        'created_at': '2026-09-20T00:00:00Z',
        'handled_at': '2026-09-21T00:00:00Z',
        'closed_at': '2026-09-22T00:00:00Z',
        'reporter_response': 'Baik.',
        'resolution_note': 'Internal.',
      });
      expect(full.closedAt?.day, 22);
      expect(full.reporterResponse, 'Baik.');
      expect(full.resolutionNote, 'Internal.');

      // Old projections without the new columns still parse.
      final legacy = BkPeerConcern.fromMap({
        'concern_id': '1',
        'target_display': 't',
        'reason': 'emotional',
        'status': 'pending',
        'created_at': '2026-09-20T00:00:00Z',
      });
      expect(legacy.closedAt, isNull);
      expect(legacy.reporterResponse, isNull);
      expect(legacy.resolutionNote, isNull);
    });
  });

  group('student history closure display', () {
    Future<void> pumpHistory(
      WidgetTester tester,
      List<BkPeerConcern> items,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentPeerConcernsProvider.overrideWith((ref) async => items),
          ],
          child: const MaterialApp(home: BkPeerConcernHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('resolved shows status, closure date and response', (
      tester,
    ) async {
      await pumpHistory(tester, [
        concern(
          status: 'resolved',
          response: 'Sudah kami tindaklanjuti.',
          closedAt: DateTime(2026, 9, 22),
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Selesai ditindaklanjuti'), findsOneWidget);
      expect(find.textContaining('Ditutup: 22/9/2026'), findsOneWidget);
      expect(find.text('Tanggapan Guru BK'), findsOneWidget);
      expect(find.text('Sudah kami tindaklanjuti.'), findsOneWidget);
    });

    testWidgets('dismissed shows distinct dismissed label', (tester) async {
      await pumpHistory(tester, [
        concern(status: 'dismissed', closedAt: DateTime(2026, 9, 23)),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Ditutup tanpa tindak lanjut'), findsOneWidget);
      expect(find.textContaining('Ditutup: 23/9/2026'), findsOneWidget);
    });

    testWidgets('null response renders cleanly without placeholder', (
      tester,
    ) async {
      await pumpHistory(tester, [
        concern(status: 'resolved', closedAt: DateTime(2026, 9, 22)),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Tanggapan Guru BK'), findsNothing);
    });

    testWidgets('internal note never leaks to student history', (tester) async {
      await pumpHistory(tester, [
        concern(
          status: 'resolved',
          response: 'Untukmu.',
          note: 'RAHASIA-INTERNAL',
          closedAt: DateTime(2026, 9, 22),
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('RAHASIA-INTERNAL'), findsNothing);
      expect(find.text('CATATAN INTERNAL'), findsNothing);
      expect(find.text('Untukmu.'), findsOneWidget);
    });
  });

  group('counselor detail closure display', () {
    Future<void> pumpDetail(WidgetTester tester, BkPeerConcern item) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peerConcernDetailProvider.overrideWith((ref, id) async => item),
          ],
          child: const MaterialApp(
            home: CounselorPeerConcernDetailPage(concernId: 'pc-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('closed concern shows dates, note and response', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        concern(
          status: 'resolved',
          response: 'Untuk pelapor.',
          note: 'Catatan BK.',
          closedAt: DateTime(2026, 9, 22),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Status akhir: Selesai ditindaklanjuti'),
        findsOneWidget,
      );
      expect(find.textContaining('Ditangani: 21/9/2026'), findsOneWidget);
      expect(find.textContaining('Ditutup: 22/9/2026'), findsOneWidget);
      expect(find.text('TANGGAPAN UNTUK PELAPOR'), findsOneWidget);
      expect(find.text('Untuk pelapor.'), findsOneWidget);
      expect(find.text('CATATAN INTERNAL'), findsOneWidget);
      expect(find.text('Catatan BK.'), findsOneWidget);
    });

    testWidgets('null notes render cleanly', (tester) async {
      await pumpDetail(
        tester,
        concern(status: 'dismissed', closedAt: DateTime(2026, 9, 23)),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text('Status akhir: Ditutup tanpa tindak lanjut'),
        findsOneWidget,
      );
      expect(find.text('TANGGAPAN UNTUK PELAPOR'), findsNothing);
      expect(find.text('CATATAN INTERNAL'), findsNothing);
    });

    testWidgets('resolve dialog separates response and internal note', (
      tester,
    ) async {
      await pumpDetail(tester, concern(status: 'reviewing'));
      await tester.tap(find.text('Tandai Selesai'));
      await tester.pumpAndSettle();
      expect(find.text('Tanggapan untuk pelapor'), findsOneWidget);
      expect(find.text('Catatan internal BK'), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      for (final f in fields) {
        expect(f.maxLength, 2000);
      }
    });
  });

  group('resolve/dismiss controller forwards both notes', () {
    ProviderContainer containerWith(_FakePeerConcernRepo repo) {
      final container = ProviderContainer(
        overrides: [peerConcernRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('resolved flow sends note and response', () async {
      final repo = _FakePeerConcernRepo();
      final container = containerWith(repo);
      final err = await container
          .read(peerConcernControllerProvider.notifier)
          .resolve('pc-1', note: 'internal', response: 'untuk pelapor');
      expect(err, isNull);
      expect(repo.resolvedIds, ['pc-1']);
      expect(repo.lastNote, 'internal');
      expect(repo.lastResponse, 'untuk pelapor');
    });

    test('dismissed flow sends note and response', () async {
      final repo = _FakePeerConcernRepo();
      final container = containerWith(repo);
      final err = await container
          .read(peerConcernControllerProvider.notifier)
          .dismiss('pc-1', note: 'internal', response: 'untuk pelapor');
      expect(err, isNull);
      expect(repo.dismissedIds, ['pc-1']);
      expect(repo.lastNote, 'internal');
      expect(repo.lastResponse, 'untuk pelapor');
    });
  });
}

/// In-memory stand-in recording resolve/dismiss note + response payloads.
class _FakePeerConcernRepo extends PeerConcernRepository {
  _FakePeerConcernRepo()
    : super(
        SupabaseClient(
          'http://localhost:1',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final List<String> resolvedIds = [];
  final List<String> dismissedIds = [];
  String? lastNote;
  String? lastResponse;

  @override
  Future<void> resolve(
    String concernId, {
    String? note,
    String? response,
  }) async {
    resolvedIds.add(concernId);
    lastNote = note;
    lastResponse = response;
  }

  @override
  Future<void> dismiss(
    String concernId, {
    String? note,
    String? response,
  }) async {
    dismissedIds.add(concernId);
    lastNote = note;
    lastResponse = response;
  }
}
