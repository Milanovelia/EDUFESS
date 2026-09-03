import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/counseling/data/models/bk_peer_concern.dart';
import 'package:edufess/features/counseling/presentation/providers/peer_concern_providers.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_peer_concern_page.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_peer_concern_history_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_peer_concern_queue_page.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_peer_concern_detail_page.dart';

BkPeerConcern _concern(String id, String target, String status) => BkPeerConcern(
      id: id,
      targetDisplay: target,
      reason: 'emotional',
      status: status,
      createdAt: DateTime.now(),
    );

void main() {
  group('BkPeerConcern model', () {
    test('reason labels', () {
      expect(BkPeerConcern(id: '1', targetDisplay: 't', reason: 'emotional', status: 'pending', createdAt: DateTime.now()).reasonLabel, 'Kondisi Emosional');
      expect(BkPeerConcern(id: '1', targetDisplay: 't', reason: 'bullying', status: 'pending', createdAt: DateTime.now()).reasonLabel, 'Perundungan');
    });

    test('status labels', () {
      expect(BkPeerConcern(id: '1', targetDisplay: 't', reason: 'emotional', status: 'pending', createdAt: DateTime.now()).statusLabel, 'Menunggu');
      expect(BkPeerConcern(id: '1', targetDisplay: 't', reason: 'emotional', status: 'reviewing', createdAt: DateTime.now()).statusLabel, 'Sedang Ditinjau');
    });
  });

  group('Student Peduli Teman', () {
    testWidgets('shows search and reason', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: BkPeerConcernPage()),
        ),
      );
      expect(find.text('Peduli Teman'), findsOneWidget);
      expect(find.text('Cari pseudonim teman'), findsOneWidget);
      expect(find.text('Sampaikan Kepedulian'), findsOneWidget);
    });

    testWidgets('shows privacy copy', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: BkPeerConcernPage()),
        ),
      );
      expect(find.textContaining('hanya digunakan dalam layanan BK'), findsOneWidget);
    });

    testWidgets('student history empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studentPeerConcernsProvider.overrideWith((ref) async => [])],
          child: const MaterialApp(home: BkPeerConcernHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Belum ada kepedulian yang kamu sampaikan.'), findsOneWidget);
    });

    testWidgets('student history shows concerns', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentPeerConcernsProvider.overrideWith((ref) async => [_concern('1', 'M10_Student2', 'pending')]),
          ],
          child: const MaterialApp(home: BkPeerConcernHistoryPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('M10_Student2'), findsOneWidget);
      expect(find.text('Menunggu'), findsOneWidget);
    });
  });

  group('Counselor Peer Concern', () {
    testWidgets('queue shows alias only', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorPeerConcernQueueProvider.overrideWith((ref) async => [_concern('1', 'M10_Student1', 'pending')]),
            counselorPeerConcernHistoryProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: CounselorPeerConcernQueuePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('M10_Student1'), findsOneWidget);
      expect(find.text('Tangani'), findsOneWidget);
      // Should not show reporter identity
      expect(find.textContaining('reporter'), findsNothing);
    });

    testWidgets('queue empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorPeerConcernQueueProvider.overrideWith((ref) async => []),
            counselorPeerConcernHistoryProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: CounselorPeerConcernQueuePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada laporan yang menunggu.'), findsOneWidget);
    });

    testWidgets('detail shows resolve/dismiss', (tester) async {
      final concern = BkPeerConcern(id: '1', targetDisplay: 'M10_Student1', reason: 'emotional', details: 'Detail', status: 'reviewing', createdAt: DateTime.now());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [peerConcernDetailProvider.overrideWith((ref, id) async => concern)],
          child: const MaterialApp(home: CounselorPeerConcernDetailPage(concernId: '1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('M10_Student1'), findsOneWidget);
      expect(find.text('Tandai Selesai'), findsOneWidget);
      expect(find.text('Tutup Tanpa Tindak Lanjut'), findsOneWidget);
    });
  });

  group('Peer search privacy', () {
    test('PeerStudent model', () {
      final p = PeerStudent(studentRef: 'ref1', displayPseudonym: 'M10_Student1');
      expect(p.displayPseudonym, 'M10_Student1');
    });
  });
}
