import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edufess/features/auth/data/profile_repository.dart';
import 'package:edufess/features/auth/presentation/providers/auth_controller.dart';
import 'package:edufess/features/profile/presentation/pages/profile_page.dart';

Future<void> _pumpProfile(
  WidgetTester tester, {
  required Future<UserProfile?> Function() fetch,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentProfileProvider.overrideWith((ref) => fetch())],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders pseudonym, avatar initial, and one logout affordance', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      fetch: () async =>
          const UserProfile(id: 'u1', pseudonym: 'santri', role: 'student'),
    );

    expect(find.text('santri'), findsOneWidget);
    expect(find.text('Nama tampilan di komunitas'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);

    final context = tester.element(find.byType(ProfilePage));
    final scheme = Theme.of(context).colorScheme;
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, scheme.secondaryContainer);

    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Keluar'), findsNothing);
  });

  testWidgets('shows a friendly error with a retry that recovers', (
    tester,
  ) async {
    var calls = 0;
    await _pumpProfile(
      tester,
      fetch: () async {
        calls++;
        if (calls == 1) throw StateError('boom-secret');
        return const UserProfile(
          id: 'u1',
          pseudonym: 'santri',
          role: 'student',
        );
      },
    );

    expect(find.text('Gagal memuat profil'), findsOneWidget);
    expect(find.text('Periksa koneksi kamu lalu coba lagi.'), findsOneWidget);
    expect(find.textContaining('boom-secret'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('santri'), findsOneWidget);
  });

  testWidgets('missing profile offers a reload action', (tester) async {
    await _pumpProfile(tester, fetch: () async => null);

    expect(find.text('Profil tidak ditemukan'), findsOneWidget);
    expect(find.text('Muat ulang'), findsOneWidget);
  });
}
