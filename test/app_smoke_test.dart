import 'package:edufess/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots into the Home tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EdufessApp()));
    await tester.pumpAndSettle();

    expect(
      find.text('Feed catatan, rangkuman, dan diskusi akan muncul di sini.'),
      findsOneWidget,
    );
  });

  testWidgets('bottom navigation exposes the five destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: EdufessApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('tapping BK switches to the counseling placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: EdufessApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ruang privat untuk dukungan siswa. Terpisah dari feed publik.'),
      findsOneWidget,
    );
  });
}
