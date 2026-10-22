import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:edufess/app/theme/app_theme.dart';
import 'package:edufess/core/constants/app_spacing.dart';
import 'package:edufess/core/widgets/state_views.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('light theme tokens', () {
    final theme = AppTheme.light();
    final scheme = theme.colorScheme;

    test('uses neutral surfaces with plum as accent only', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAFA));
      expect(scheme.surface, const Color(0xFFFAFAFA));
      expect(scheme.surfaceContainerLow, const Color(0xFFFCFCFC));
      expect(scheme.surfaceContainerHighest, const Color(0xFFEFEFF0));
      expect(scheme.onSurface, const Color(0xFF2C2C2B));
      expect(scheme.primary, const Color(0xFF22262A));
      expect(scheme.onPrimary, const Color(0xFFF9FAFB));
      expect(scheme.secondary, AppTheme.seedColor);
      expect(scheme.outlineVariant, const Color(0xFFE0E0E3));
      expect(theme.cardTheme.color, scheme.surfaceContainerLow);
      expect(theme.cardTheme.elevation, 0);
    });

    test('text and brand pairings meet AA contrast', () {
      expect(
        _contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.secondary, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(theme.extension<AppPalette>()!.positive, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('centralizes a compact type scale', () {
      expect(theme.textTheme.bodyMedium?.fontSize, 14);
      expect(theme.textTheme.bodyMedium?.height, 1.5);
      expect(theme.textTheme.bodySmall?.fontSize, 12.25);
      expect(theme.textTheme.titleSmall?.fontSize, 14);
      expect(theme.textTheme.titleSmall?.fontWeight, FontWeight.w600);
      expect(theme.textTheme.titleMedium?.fontSize, 15.75);
      expect(theme.textTheme.titleLarge?.fontSize, 17.5);
      expect(theme.textTheme.headlineMedium?.fontSize, 21);
      expect(theme.textTheme.headlineLarge?.fontSize, 26.25);
      expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
      expect(theme.textTheme.labelSmall?.fontSize, 10.5);
      expect(theme.appBarTheme.titleTextStyle?.fontSize, 18);
    });

    test('uses restrained radii and a compact primary CTA', () {
      expect(AppRadius.sm, 7);
      expect(AppRadius.md, 11);
      expect(AppRadius.lg, 14);

      final inputBorder =
          theme.inputDecorationTheme.border! as OutlineInputBorder;
      expect(inputBorder.borderRadius, BorderRadius.circular(AppRadius.sm));

      final focusedBorder =
          theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
      expect(focusedBorder.borderSide.color, scheme.primary);
      expect(focusedBorder.borderSide.width, 1.5);

      final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(cardShape.borderRadius, BorderRadius.circular(AppRadius.md));

      final filledShape =
          theme.filledButtonTheme.style!.shape!.resolve(const <WidgetState>{})!
              as RoundedRectangleBorder;
      expect(filledShape.borderRadius, BorderRadius.circular(AppRadius.md));
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve(
          const <WidgetState>{},
        ),
        const Size.fromHeight(48),
      );
    });

    test('keeps selected and focused states distinguishable', () {
      expect(theme.chipTheme.secondarySelectedColor, scheme.secondaryContainer);
      expect(theme.chipTheme.side?.color, scheme.outlineVariant);
      expect(
        theme.chipTheme.secondaryLabelStyle?.color,
        scheme.onSecondaryContainer,
      );
      expect(
        theme.colorScheme.primaryContainer,
        isNot(theme.colorScheme.primary),
      );
    });
  });

  group('dark theme tokens', () {
    final theme = AppTheme.dark();
    final scheme = theme.colorScheme;

    test('uses neutral surfaces with readable ink primary', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1A1A1A));
      expect(scheme.surface, const Color(0xFF1A1A1A));
      expect(scheme.surfaceContainerLow, const Color(0xFF212121));
      expect(scheme.surfaceContainerHighest, const Color(0xFF333333));
      expect(scheme.onSurface, const Color(0xFFEFEEEB));
      expect(scheme.primary, const Color(0xFFF9FAFB));
      expect(scheme.onPrimary, const Color(0xFF22262A));
      expect(scheme.outlineVariant, const Color(0xFF2E2E33));
      expect(theme.cardTheme.color, scheme.surfaceContainerLow);
    });

    test('adjusts destructive and positive tokens for dark contrast', () {
      expect(
        _contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.error, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(scheme.secondary, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
          theme.extension<AppPalette>()!.positive,
          scheme.surfaceContainerLow,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('shared state views', () {
    testWidgets('empty state is compact and muted', (tester) async {
      final theme = AppTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: EmptyStateView(
              icon: Icons.search_off,
              title: 'Tidak ada hasil',
              message: 'Coba kata kunci lain.',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.search_off));
      expect(icon.size, 24);
      expect(icon.color, theme.colorScheme.onSurfaceVariant);

      final title = tester.widget<Text>(find.text('Tidak ada hasil'));
      expect(title.style?.fontSize, 14);
      expect(title.style?.fontWeight, FontWeight.w600);

      final message = tester.widget<Text>(find.text('Coba kata kunci lain.'));
      expect(message.style?.fontSize, 12.25);
      expect(message.style?.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('error state keeps a working compact retry action', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ErrorStateView(
              message: 'Periksa koneksi kamu.',
              onRetry: () => retries++,
            ),
          ),
        ),
      );

      expect(find.text('Terjadi kesalahan'), findsOneWidget);
      expect(find.text('Periksa koneksi kamu.'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Coba lagi'),
      );
      expect(
        button.style?.minimumSize?.resolve(const <WidgetState>{}),
        const Size(0, 42),
      );

      await tester.tap(find.text('Coba lagi'));
      expect(retries, 1);
    });

    testWidgets('refreshable state remains scrollable for pull-to-refresh', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RefreshableStateView(
              onRefresh: () async {},
              child: const EmptyStateView(
                icon: Icons.inbox_outlined,
                title: 'Kosong',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    });
  });
}
