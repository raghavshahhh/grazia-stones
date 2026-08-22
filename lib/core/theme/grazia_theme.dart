import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/borders.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

/// Builds the app's ThemeData from a [LuxuryPalette].
/// Defaults to [GLuxuryPalettes.gold] (Grazia branding).
class GraziaTheme {
  GraziaTheme._();

  static ThemeData light([LuxuryPalette? palette]) {
    final p = palette ?? GLuxuryPalettes.gold;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme.light(
        primary: p.primary,
        onPrimary: Colors.white,
        secondary: p.secondary,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: p.error,
        onError: Colors.white,
      ),
      textTheme: GLuxuryTypography.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GLuxuryTypography.labelLarge.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: p.textPrimary, size: GTokens.iconMd),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GLuxuryTypography.labelSmall.copyWith(
          color: p.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GLuxuryTypography.labelSmall.copyWith(
          color: p.textTertiary,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GLuxuryBorders.radiusLg,
          side: BorderSide(color: p.border),
        ),
      ),

      // ── Text Fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: GLuxuryTypography.bodyMedium.copyWith(
          color: p.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GLuxurySpacing.base,
          vertical: GLuxurySpacing.sm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.error),
        ),
      ),

      // ── Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, GTokens.space12 + 8),
          shape: RoundedRectangleBorder(
            borderRadius: GLuxuryBorders.buttonRadius,
          ),
          elevation: 0,
          textStyle: GLuxuryTypography.labelLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, GTokens.space12 + 8),
          shape: RoundedRectangleBorder(
            borderRadius: GLuxuryBorders.buttonRadius,
          ),
          side: BorderSide(color: p.border, width: 1.2),
          foregroundColor: p.textPrimary,
          textStyle: GLuxuryTypography.labelLarge.copyWith(
            color: p.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 0.8,
        space: GLuxurySpacing.lg,
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceDark,
        selectedColor: p.primary,
        disabledColor: p.surfaceDark,
        labelStyle: GLuxuryTypography.labelMedium.copyWith(color: p.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: GLuxuryBorders.chipRadius,
        ),
        side: BorderSide(color: p.border),
        padding: const EdgeInsets.symmetric(
          horizontal: GLuxurySpacing.sm,
          vertical: GLuxurySpacing.xs,
        ),
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: GLuxuryBorders.bottomSheetRadius,
        ),
      ),
    );
  }

  static ThemeData dark([LuxuryPalette? palette]) {
    final p = palette ?? GLuxuryPalettes.goldDark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme.dark(
        primary: p.primary,
        onPrimary: p.background,
        secondary: p.secondary,
        onSecondary: p.background,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: p.error,
        onError: p.textPrimary,
      ),
      textTheme: GLuxuryTypography.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GLuxuryTypography.labelLarge.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: p.textSecondary, size: GTokens.iconMd),
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GLuxuryTypography.labelSmall.copyWith(
          color: p.primary,
        ),
        unselectedLabelStyle: GLuxuryTypography.labelSmall.copyWith(
          color: p.textTertiary,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: GLuxuryBorders.radiusLg,
          side: BorderSide(color: p.border),
        ),
      ),

      // ── Text Fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        hintStyle: GLuxuryTypography.bodyMedium.copyWith(
          color: p.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GLuxurySpacing.base,
          vertical: GLuxurySpacing.sm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: GLuxuryBorders.radiusMd,
          borderSide: BorderSide(color: p.error),
        ),
      ),

      // ── Buttons ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.background,
          minimumSize: const Size(double.infinity, GTokens.space12 + 8),
          shape: RoundedRectangleBorder(
            borderRadius: GLuxuryBorders.buttonRadius,
          ),
          elevation: 0,
          textStyle: GLuxuryTypography.labelLarge.copyWith(
            color: p.background,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, GTokens.space12 + 8),
          shape: RoundedRectangleBorder(
            borderRadius: GLuxuryBorders.buttonRadius,
          ),
          side: BorderSide(color: p.textTertiary, width: 1.5),
          foregroundColor: p.textSecondary,
          textStyle: GLuxuryTypography.labelLarge.copyWith(
            color: p.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 0.5,
        space: GLuxurySpacing.lg,
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.primary,
        disabledColor: p.surfaceDark,
        labelStyle: GLuxuryTypography.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: GLuxuryBorders.chipRadius,
        ),
        side: BorderSide(color: p.border),
        padding: const EdgeInsets.symmetric(
          horizontal: GLuxurySpacing.sm,
          vertical: GLuxurySpacing.xs,
        ),
      ),

      // ── Bottom Sheet ──
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: GLuxuryBorders.bottomSheetRadius,
        ),
      ),
    );
  }
}
