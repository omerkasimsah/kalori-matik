import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => _build(AppPalette.light);
  static ThemeData get darkTheme => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final isDark = p.brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      brightness: p.brightness,
      seedColor: p.primary,
    ).copyWith(
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.mid,
      onSecondary: p.onPrimary,
      surface: p.background,
      onSurface: p.text,
      surfaceVariant: p.surface,
      outline: p.divider,
      error: const Color(0xFFE5484D),
    );

    TextStyle inter(double size, FontWeight w, Color c) =>
        GoogleFonts.inter(fontSize: size, fontWeight: w, color: c);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      primaryColor: p.primary,
      scaffoldBackgroundColor: p.background,
      colorScheme: base,
      splashFactory: InkRipple.splashFactory,
      dividerColor: p.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: p.text),
        titleTextStyle: inter(18, FontWeight.w700, p.text),
      ),
      textTheme: TextTheme(
        displayLarge: inter(32, FontWeight.w900, p.text),
        headlineMedium: inter(24, FontWeight.w800, p.text),
        titleLarge: inter(20, FontWeight.w700, p.text),
        titleMedium: inter(16, FontWeight.w600, p.text),
        titleSmall: inter(13, FontWeight.w600, p.textSecondary)
            .copyWith(letterSpacing: 0.5),
        bodyLarge: inter(16, FontWeight.w400, p.text),
        bodyMedium: inter(14, FontWeight.w400, p.text),
        bodySmall: inter(12, FontWeight.w400, p.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surface,
          disabledForegroundColor: p.textHint,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: inter(15, FontWeight.w800, p.onPrimary),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.divider, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: inter(15, FontWeight.w700, p.text),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          textStyle: inter(14, FontWeight.w700, p.text),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.cardSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(Colors.transparent, 0),
        enabledBorder: border(Colors.transparent, 0),
        focusedBorder: border(p.primary, 1.5),
        errorBorder: border(const Color(0xFFE5484D)),
        focusedErrorBorder: border(const Color(0xFFE5484D), 1.5),
        hintStyle: inter(14, FontWeight.w400, p.textHint),
        labelStyle: inter(14, FontWeight.w400, p.textSecondary),
        floatingLabelStyle: inter(14, FontWeight.w600, p.text),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: p.cardSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.cardSurface,
        selectedColor: p.primary,
        side: BorderSide.none,
        labelStyle: inter(12, FontWeight.w700, p.text),
        secondaryLabelStyle: inter(12, FontWeight.w700, p.onPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.divider,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: inter(18, FontWeight.w800, p.text),
        contentTextStyle: inter(14, FontWeight.w400, p.textSecondary),
      ),
      dividerTheme: DividerThemeData(color: p.divider, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.text,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surface,
        circularTrackColor: p.surface,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        thumbColor: p.primary,
        inactiveTrackColor: p.surface,
        overlayColor: p.primary.withAlpha(30),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? p.onPrimary : p.mid),
        trackColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? p.primary : p.surface),
        trackOutlineColor: MaterialStatePropertyAll(
            isDark ? Colors.transparent : p.divider),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: p.text,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.primary,
        dividerColor: p.divider,
        labelStyle: inter(12, FontWeight.w800, p.text),
        unselectedLabelStyle: inter(12, FontWeight.w600, p.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.primary,
        contentTextStyle: inter(14, FontWeight.w600, p.onPrimary),
        actionTextColor: p.onPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
