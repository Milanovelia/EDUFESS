import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/app/theme/app_theme.dart';
import 'package:edufess/features/auth/data/profile_repository.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';
import 'package:edufess/features/counseling/data/models/bk_conversation.dart';
import 'package:edufess/features/counseling/presentation/pages/bk_conversation_page.dart';
import 'package:edufess/features/counseling/presentation/providers/counseling_providers.dart';

/// BK-02 regression: the conversation composer placed a [FilledButton]
/// directly in a horizontal [Row] while [AppTheme] sets button
/// `minimumSize` width to infinite. The button then received unbounded
/// width with an infinite minimum and threw
/// "BoxConstraints forces an infinite width", blanking the page on device.
///
/// These tests pump the REAL app theme at phone size, which is what the
/// older tests missed (default [MaterialApp] theme has finite minima).
void main() {
  BkConversation conv() => BkConversation(
    id: 'conv1',
    studentAlias: 'Siswa BK #A1B2',
    status: 'open',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  BkMessage msg(String content) => BkMessage(
    id: 'm-${content.length}',
    content: content,
    createdAt: DateTime.now(),
    isMine: false,
  );

  Future<void> pumpConversation(
    WidgetTester tester,
    List<BkMessage> messages,
  ) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (ref) async =>
                const UserProfile(id: '1', pseudonym: 's1', role: 'student'),
          ),
          bkConversationProvider.overrideWith((ref, id) async => conv()),
          counselingMessagesProvider.overrideWith((ref, id) async => messages),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const BkConversationPage(conversationId: 'conv1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('BK-02 conversation composer layout (AppTheme, phone size)', () {
    testWidgets('empty conversation renders without exception', (tester) async {
      await pumpConversation(tester, []);
      expect(tester.takeException(), isNull);
      // Empty state, composer, input and send action are all visible.
      expect(find.textContaining('Belum ada pesan.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);
      expect(find.text('Identitas BK kamu: Siswa BK #A1B2'), findsOneWidget);
    });

    testWidgets('one message renders without exception', (tester) async {
      await pumpConversation(tester, [msg('Halo, saya butuh bantuan.')]);
      expect(tester.takeException(), isNull);
      expect(find.text('Halo, saya butuh bantuan.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);
    });

    testWidgets('long message renders without exception', (tester) async {
      await pumpConversation(tester, [msg('Penting! ' * 60)]);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Penting!'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Kirim'), findsOneWidget);
    });
  });
}
