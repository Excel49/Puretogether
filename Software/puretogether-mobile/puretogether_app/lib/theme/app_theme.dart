import 'package:flutter/material.dart';

class AppTheme {
  // ── Backgrounds & Surfaces (Light Theme) ─────────────────────
  static const Color background     = Color(0xFFF4F7FB);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceSubtle  = Color(0xFFF8FAFD);
  static const Color surfaceElevated = Color(0xFFF1F5F9);
  static const Color surfaceBorder  = Color(0xFFE2E8F2);

  // ── Brand Blue Palette ───────────────────────────────────────
  static const Color primary        = Color(0xFF1B68D2);
  static const Color primaryDark    = Color(0xFF104A9E);
  static const Color primaryLight   = Color(0xFFE8F1FC);
  static const Color primaryGlow    = Color(0x261B68D2);

  // ── Status Colors ────────────────────────────────────────────
  static const Color safe           = Color(0xFF10B981); // Emerald Green
  static const Color safeLight      = Color(0xFFE8F8F0);
  static const Color warning        = Color(0xFFF59E0B); // Amber/Orange
  static const Color warningLight   = Color(0xFFFFF7E6);
  static const Color danger         = Color(0xFFEF4444); // Red
  static const Color dangerLight    = Color(0xFFFEECEC);
  static const Color offline        = Color(0xFF64748B);
  static const Color offlineLight   = Color(0xFFF1F5F9);

  // ── Text Colors ──────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF0F1E36);
  static const Color textSecondary  = Color(0xFF64748B);
  static const Color textMuted      = Color(0xFF94A3B8);

  // ── Track Lines (Map) ────────────────────────────────────────
  static const Color lineA          = Color(0xFFF59E0B); // Orange
  static const Color lineB          = Color(0xFF1B68D2); // Blue (Active)
  static const Color lineC          = Color(0xFF10B981); // Green

  static Color statusColor(String status) {
    switch (status) {
      case 'GOOD':    return safe;
      case 'WARNING': return warning;
      case 'POOR':    return danger;
      default:        return offline;
    }
  }

  static Color statusLightColor(String status) {
    switch (status) {
      case 'GOOD':    return safeLight;
      case 'WARNING': return warningLight;
      case 'POOR':    return dangerLight;
      default:        return offlineLight;
    }
  }

  static Color statusGlow(String status) => statusColor(status).withValues(alpha: 0.15);

  static Color lineColor(String? line) {
    switch (line) {
      case 'A': return lineA;
      case 'B': return lineB;
      case 'C': return lineC;
      default:  return textMuted;
    }
  }

  static ThemeData lightTheme([TextTheme? base]) {
    final textTheme = (base ?? ThemeData.light().textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
      fontFamily: 'Inter',
    );
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      dividerColor: surfaceBorder,
      cardColor: surface,
    );
  }

  // Alias for backward compatibility if any files still call dark()
  static ThemeData dark([TextTheme? base]) => lightTheme(base);
}
