import 'package:flutter/material.dart';

/// Uygulamanın global renk paleti — Patch 4.0 (The Elite Midnight) Yenilemesi
/// Karanlık Zeminler + Neon Parlaklıklar ile "Hardcore Gym & Premium Tracker" Hissiyatı
class AppColors {
  // ── ANA VURGU RENKLERİ (NEON / ELITE) ────────────────────────────────────
  // Enerji ve Aksiyon: Neon Zümrüt Yeşili (Emerald/Mint - Aksiyon ve Doğrulama)
  static const Color primary = Color(0xFF00FF9D); 
  static const Color primaryDark = Color(0xFF00CC7E);
  static const Color primaryLight = Color(0xFF66FFA9);

  // İkincil Aksiyon: Elektrik Mavisi/Cyan (Odaklanma, Soğukkanlılık)
  static const Color secondary = Color(0xFF00E5FF); 
  static const Color secondaryDark = Color(0xFF00B2CC);

  // ── AKSİYON VE UYARI RENKLERİ ───────────────────────────────────────────
  // Kriz anları ve yaklaşılan limitler için (Canlı Turuncu/Kırmızı)
  static const Color warning = Color(0xFFFF5722); // Deep Neon Orange
  static const Color danger = Color(0xFFFF1744); // Neon Red
  static const Color success = Color(0xFF00FF9D); // Neon Emerald

  // ── ARKA PLAN VE YÜZEY (MIDNIGHT DARK MODE) ─────────────────────────────
  // Uygulamanın ana kaportası (Simsiyah değil, ultra koyu lacivert/uzay grisi)
  static const Color background = Color(0xFF0B0F19); // Çok derin gece mavisi
  static const Color surface = Color(0xFF151B2B); // Pop-up'lar ve Navigasyon
  static const Color cardSurface = Color(0xFF1E2638); // Veri Kartları

  // ── TİPOGRAFİ ───────────────────────────────────────────────────────────
  // Karanlık zeminde göz yormayan, okunaklı metinler
  static const Color textPrimary = Color(0xFFFFFFFF); // Tam beyaz (Başlıklar)
  static const Color textSecondary = Color(0xFF8B96A5); // Gri-Mavi (Alt yazılar)
  static const Color textHint = Color(0xFF4A5568); // Yarı görünmez rehberler

  // ── GRADİENT TANIMLAMALARI ──────────────────────────────────────────────
  // Ana Elite Gradient: Neon Yeşil → Neon Cyan
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00FF9D), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hardcore Gradient (Antrenman): Kan Kırmızı → Neon Turuncu
  static const LinearGradient energyGradient = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFFF5722)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Soğuma Gradient: Koyu Mor → Cyan
  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF651FFF), Color(0xFF00E5FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Cam Efekti: Koyu zeminde buzlu cam (Glassmorphism)
  static Color glassDark = const Color(0xFF151B2B).withAlpha(150);
}
