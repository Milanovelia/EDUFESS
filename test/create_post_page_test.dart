import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edufess/features/create_post/presentation/pages/create_post_page.dart';

void main() {
  testWidgets('CreatePostPage renders composer', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePostPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buat Post'), findsOneWidget);
    expect(find.text('Apa yang sedang kamu pikirkan?'), findsOneWidget);
    expect(find.text('Judul *'), findsOneWidget);
    expect(find.text('Posting'), findsOneWidget);
    // Type chips + compact anon toggle replace the old dropdowns.
    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('Publik'), findsOneWidget);
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
    await tester.tap(find.text('Posting'), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Title + content validators still block empty submission.
    expect(find.text('Judul wajib diisi.'), findsOneWidget);
    expect(find.text('Konten wajib diisi.'), findsOneWidget);
  });

  testWidgets('CreatePostPage type chips are selectable', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePostPage())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pertanyaan'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('CreatePostPage anon toggle preserves semantics', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePostPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tampil sebagai pseudonym kamu'), findsOneWidget);
    await tester.tap(find.text('Publik'));
    await tester.pumpAndSettle();
    expect(find.text('Anonim'), findsOneWidget);
    expect(find.text('Disamarkan sebagai Siswa Anonim'), findsOneWidget);
  });
}
