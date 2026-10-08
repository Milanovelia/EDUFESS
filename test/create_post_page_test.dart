import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/create_post/presentation/pages/create_post_page.dart';

void main() {
  testWidgets('CreatePostPage renders form', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePostPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buat Post'), findsOneWidget);
    expect(find.text('Judul *'), findsOneWidget);
    expect(find.text('Konten *'), findsOneWidget);
    // Button is inside ListView, may need scroll
    expect(find.text('Posting', skipOffstage: false), findsOneWidget);
  });

  testWidgets('CreatePostPage has no subject picker', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePostPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mata Pelajaran *'), findsNothing);
    expect(find.text('Topik (opsional)'), findsNothing);
  });

  testWidgets('CreatePostPage validates required fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePostPage())),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Posting', skipOffstage: false), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Should show validation errors for title/content
    expect(find.text('Judul wajib diisi.'), findsOneWidget);
  });
}
