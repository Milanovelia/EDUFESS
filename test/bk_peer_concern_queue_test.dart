import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/app/theme/app_theme.dart';
import 'package:edufess/features/counseling/data/models/bk_peer_concern.dart';
import 'package:edufess/features/counseling/presentation/pages/counselor_peer_concern_queue_page.dart';
import 'package:edufess/features/counseling/presentation/providers/peer_concern_providers.dart';

/// BK-PC-01 regression: the counselor queue `ListTile(trailing:
/// FilledButton('Tangani'))` crashed under the real [AppTheme], whose
/// button `minimumSize` width is infinite. ListTile trailing receives
/// unbounded horizontal width, so the button broke `_RenderListTile`
/// layout and the concern item could not render.
///
/// Pumped with [AppTheme.light()] at phone size — the default test theme
/// has finite button minima and cannot reproduce this class of defect.
/// Only privacy-safe fields (alias, reason, date) are asserted; reporter
/// identity and concern text are never exposed.
void main() {
  BkPeerConcern queuedConcern() => BkPeerConcern(
    id: 'pc-1',
    targetDisplay: 'Siswa BK #D4FF',
    reason: 'emotional',
    status: 'pending',
    createdAt: DateTime.now(),
  );

  Future<void> pumpQueuePage(
    WidgetTester tester,
    List<BkPeerConcern> queue,
  ) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          counselorPeerConcernQueueProvider.overrideWith((ref) async => queue),
          counselorPeerConcernHistoryProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CounselorPeerConcernQueuePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('BK-PC-01 counselor queue layout (AppTheme, phone size)', () {
    testWidgets('non-empty queue renders without exception', (tester) async {
      await pumpQueuePage(tester, [queuedConcern()]);
      expect(tester.takeException(), isNull);
      // Privacy-safe queue fields only: alias + reason, no reporter identity.
      expect(find.text('Siswa BK #D4FF'), findsOneWidget);
      expect(find.text('Kondisi Emosional'), findsOneWidget);
      expect(find.text('Tangani'), findsOneWidget);
    });

    testWidgets('empty queue renders valid empty state', (tester) async {
      await pumpQueuePage(tester, []);
      expect(tester.takeException(), isNull);
      expect(find.text('Tidak ada laporan yang menunggu.'), findsOneWidget);
    });
  });
}
