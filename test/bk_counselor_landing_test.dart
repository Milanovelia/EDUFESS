import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/app/theme/app_theme.dart';
import 'package:edufess/features/auth/data/profile_repository.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';
import 'package:edufess/features/counseling/data/models/bk_conversation.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';

/// BK-03 regression: the counselor queue `ListTile(trailing:
/// FilledButton('Tangani'))` crashed under the real [AppTheme], whose
/// button `minimumSize` width is infinite. ListTile trailing receives
/// unbounded horizontal width, so the button threw
/// "BoxConstraints forces an infinite width" whenever the queue held at
/// least one item, blanking the counselor BK landing.
///
/// Pumped with [AppTheme.light()] at phone size — the default test theme
/// has finite button minima and cannot reproduce this class of defect.
void main() {
  Future<void> pumpCounselorLanding(
    WidgetTester tester, {
    required List<BkConversation> queue,
  }) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'c1',
              pseudonym: 'conselor',
              role: 'counselor',
            ),
          ),
          counselorQueueProvider.overrideWith((ref) async => queue),
          counselorAssignedProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const BkPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  BkConversation queuedConv() => BkConversation(
    id: 'conv-1',
    studentAlias: 'Siswa BK #A1B2',
    status: 'open',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  group('BK-03 counselor landing layout (AppTheme, phone size)', () {
    testWidgets('non-empty queue renders without exception', (tester) async {
      await pumpCounselorLanding(tester, queue: [queuedConv()]);
      expect(tester.takeException(), isNull);
      // Queue item alias and claim action are visible on Antrean tab.
      expect(find.text('Siswa BK #A1B2'), findsOneWidget);
      expect(find.text('Tangani'), findsOneWidget);
      expect(find.text('Antrean'), findsOneWidget);
      expect(find.text('Ditangani'), findsOneWidget);
    });

    testWidgets('empty queue renders valid empty state', (tester) async {
      await pumpCounselorLanding(tester, queue: []);
      expect(tester.takeException(), isNull);
      expect(find.text('Tidak ada percakapan yang menunggu.'), findsOneWidget);
    });
  });
}
