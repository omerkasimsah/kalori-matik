import 'package:flutter/material.dart';

/// Açık ve koyu temanın renk jetonları. Tasarım ilkesi: nötr (siyah-beyaz-gri)
/// bir arayüz; renk yalnızca anlam taşıyorsa (hata, uyarı, başarı) kullanılır.
class AppPalette {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color cardSurface;
  final Color divider;
  final Color text;
  final Color textSecondary;
  final Color textHint;

  /// Vurgu = ön plan rengi (açıkta siyah, koyuda beyaz). Üzerindeki yazı [onPrimary].
  final Color primary;
  final Color onPrimary;
  final Color mid; // orta gri (ikincil veri)
  final Color soft; // açık gri (üçüncül veri)

  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.cardSurface,
    required this.divider,
    required this.text,
    required this.textSecondary,
    required this.textHint,
    required this.primary,
    required this.onPrimary,
    required this.mid,
    required this.soft,
  });

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFEDEDEF),
    cardSurface: Color(0xFFF5F5F6),
    divider: Color(0xFFE3E3E6),
    text: Color(0xFF0A0A0B),
    textSecondary: Color(0xFF6B6B70),
    textHint: Color(0xFFA3A3A8),
    primary: Color(0xFF0A0A0B),
    onPrimary: Color(0xFFFFFFFF),
    mid: Color(0xFF8A8A8F),
    soft: Color(0xFFC4C4C8),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    surface: Color(0xFF1E1E20),
    cardSurface: Color(0xFF141415),
    divider: Color(0xFF272729),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9A9A9F),
    textHint: Color(0xFF5E5E63),
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    mid: Color(0xFF8E8E93),
    soft: Color(0xFF48484B),
  );
}

/// Uygulama renkleri. Değerler aktif temaya göre değişir; kök widget
/// (bkz. main.dart) tema değişince alt ağacı yeniden oluşturur.
class AppColors {
  static AppPalette _p = AppPalette.dark;

  static void apply(Brightness b) =>
      _p = b == Brightness.dark ? AppPalette.dark : AppPalette.light;

  static bool get isDark => _p.brightness == Brightness.dark;
  static AppPalette get palette => _p;

  // ── Nötr yüzeyler ────────────────────────────────────────────────────────
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get cardSurface => _p.cardSurface;
  static Color get divider => _p.divider;

  // ── Metin ────────────────────────────────────────────────────────────────
  static Color get textPrimary => _p.text;
  static Color get textSecondary => _p.textSecondary;
  static Color get textHint => _p.textHint;

  // ── Vurgu (nötr) ─────────────────────────────────────────────────────────
  static Color get primary => _p.primary;
  static Color get onPrimary => _p.onPrimary;
  static Color get primaryDark => _p.primary;
  static Color get primaryLight => _p.mid;
  static Color get secondary => _p.mid;
  static Color get secondaryDark => _p.textSecondary;

  // ── Anlamlı renkler (yalnızca durum bildirir) ────────────────────────────
  static Color get success => const Color(0xFF1F9D55);
  static Color get warning => const Color(0xFFE08A1E);
  static Color get danger => const Color(0xFFE5484D);

  // ── Veri serileri (gri tonları) ──────────────────────────────────────────
  static Color get protein => _p.primary;
  static Color get carbs => _p.mid;
  static Color get fat => _p.soft;
  static Color get water => _p.mid;

  // ── Gradyanlar (yalnızca nötr tonlar) ────────────────────────────────────
  static LinearGradient get primaryGradient => LinearGradient(
        colors: [_p.primary, _p.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  static LinearGradient get energyGradient => primaryGradient;
  static LinearGradient get coolGradient => primaryGradient;

  static Color get glassDark => _p.cardSurface.withAlpha(180);
}
