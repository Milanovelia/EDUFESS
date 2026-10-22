import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

/// Semantic colors that Material 3 does not provide a dedicated role for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required this.positive, required this.onPositive});

  /// Success/answered emphasis. The light value is darker than the pure
  /// Pensiv token so small labels stay AA-readable on neutral surfaces.
  final Color positive;

  /// Content placed directly on [positive].
  final Color onPositive;

  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ??
        AppPalette(
          positive: theme.brightness == Brightness.dark
              ? const Color(0xFF58DA88)
              : const Color(0xFF15803D),
          onPositive: theme.brightness == Brightness.dark
              ? const Color(0xFF0B2E17)
              : const Color(0xFFFFFFFF),
        );
  }

  @override
  AppPalette copyWith({Color? positive, Color? onPositive}) => AppPalette(
    positive: positive ?? this.positive,
    onPositive: onPositive ?? this.onPositive,
  );

  @override
  AppPalette lerp(covariant AppPalette? other, double t) => AppPalette(
    positive: Color.lerp(positive, other?.positive ?? positive, t)!,
    onPositive: Color.lerp(onPositive, other?.onPositive ?? onPositive, t)!,
  );
}

/// Base Material 3 theme for Edufess.
///
/// Direction: neutral, compact and editorial. Warm ink surfaces carry the
/// product, while plum stays a restrained brand accent rather than tinting
/// every surface. Screens must read style from `Theme.of(context)` instead of
/// hardcoding colors, radii or paddings.
abstract final class AppTheme {
  /// EduFess brand plum, used for accents and secondary emphasis.
  static const Color seedColor = Color(0xFF8A4A5E);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _colorScheme(brightness);
    final textTheme = _textTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'GoogleSans',
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      extensions: [
        AppPalette(
          positive: isDark ? const Color(0xFF58DA88) : const Color(0xFF15803D),
          onPositive: isDark
              ? const Color(0xFF0B2E17)
              : const Color(0xFFFFFFFF),
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.secondaryContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: AppSpacing.md,
        thickness: 1,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.secondaryContainer,
        selectionHandleColor: colorScheme.secondary,
      ),
    );
  }

  /// Neutral surface stack with EduFess plum reserved for accent roles.
  static ColorScheme _colorScheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    if (brightness == Brightness.light) {
      return base.copyWith(
        primary: const Color(0xFF22262A),
        onPrimary: const Color(0xFFF9FAFB),
        primaryContainer: const Color(0xFFE4E6E9),
        onPrimaryContainer: const Color(0xFF22262A),
        secondary: seedColor,
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: const Color(0xFFF3E4E8),
        onSecondaryContainer: const Color(0xFF3B1B26),
        tertiary: const Color(0xFF5B5F66),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: const Color(0xFFE7E8EA),
        onTertiaryContainer: const Color(0xFF2C2C2B),
        error: const Color(0xFFDC2626),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFFDE8E8),
        onErrorContainer: const Color(0xFF7F1D1D),
        surface: const Color(0xFFFAFAFA),
        onSurface: const Color(0xFF2C2C2B),
        onSurfaceVariant: const Color(0xFF6B6B70),
        surfaceContainerLowest: const Color(0xFFFCFCFC),
        surfaceContainerLow: const Color(0xFFFCFCFC),
        surfaceContainer: const Color(0xFFF5F5F6),
        surfaceContainerHigh: const Color(0xFFF2F2F3),
        surfaceContainerHighest: const Color(0xFFEFEFF0),
        outline: const Color(0xFFE0E0E3),
        outlineVariant: const Color(0xFFE0E0E3),
        inverseSurface: const Color(0xFF2C2C2B),
        onInverseSurface: const Color(0xFFF2F1EF),
        inversePrimary: const Color(0xFFD9A5B4),
        shadow: const Color(0xFF000000),
        scrim: const Color(0xFF000000),
      );
    }

    return base.copyWith(
      primary: const Color(0xFFF9FAFB),
      onPrimary: const Color(0xFF22262A),
      primaryContainer: const Color(0xFF30343A),
      onPrimaryContainer: const Color(0xFFF2F3F5),
      secondary: const Color(0xFFD9A5B4),
      onSecondary: const Color(0xFF2A1018),
      secondaryContainer: const Color(0xFF3A242B),
      onSecondaryContainer: const Color(0xFFF4D7DF),
      tertiary: const Color(0xFFB9BDC4),
      onTertiary: const Color(0xFF22262A),
      tertiaryContainer: const Color(0xFF363A40),
      onTertiaryContainer: const Color(0xFFE5E7EA),
      error: const Color(0xFFF87171),
      onError: const Color(0xFF2A0A0A),
      errorContainer: const Color(0xFF4A1D1D),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: const Color(0xFF1A1A1A),
      onSurface: const Color(0xFFEFEEEB),
      onSurfaceVariant: const Color(0xFFA1A1AA),
      surfaceContainerLowest: const Color(0xFF171717),
      surfaceContainerLow: const Color(0xFF212121),
      surfaceContainer: const Color(0xFF242424),
      surfaceContainerHigh: const Color(0xFF2A2A2A),
      surfaceContainerHighest: const Color(0xFF333333),
      outline: const Color(0xFF2E2E33),
      outlineVariant: const Color(0xFF2E2E33),
      inverseSurface: const Color(0xFFEFEEEB),
      onInverseSurface: const Color(0xFF2C2C2B),
      inversePrimary: const Color(0xFF8A4A5E),
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
  }

  /// Compact type scale, expressed in Flutter logical pixels.
  ///
  /// The base body sits at 14 with a 1.5 line height; meta text is 10.5-12.25
  /// and headings 17.5-26.25. Sizes stay in logical pixels so the platform text
  /// scaler continues to work for accessibility.
  static TextTheme _textTheme(ColorScheme colorScheme) {
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 42,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      displayMedium: TextStyle(
        fontSize: 33.25,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displaySmall: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineLarge: TextStyle(
        fontSize: 26.25,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 21,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 18.375,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 17.5,
        height: 1.3,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 15.75,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 15.75,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: TextStyle(
        fontSize: 12.25,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 12.25,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        fontSize: 10.5,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
      fontFamily: 'GoogleSans',
    );
  }
}
