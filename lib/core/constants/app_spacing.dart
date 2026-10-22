/// 8pt spacing scale used across Edufess.
///
/// Use these instead of magic numbers so screens stay visually consistent.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Shared corner radius scale.
///
/// Compact, Pensiv-inspired geometry: inputs and small controls sit near 7,
/// cards near 11, and large emphasis surfaces stay at 14.
abstract final class AppRadius {
  static const double sm = 7;
  static const double md = 11;
  static const double lg = 14;
}
