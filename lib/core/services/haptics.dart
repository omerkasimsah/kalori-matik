import 'package:flutter/services.dart';

/// Titreşim geri bildirimi. Kullanıcı ayarlardan kapatabilir.
class Haptics {
  static bool enabled = true;

  /// Hafif dokunuş: seçimler, sekme değişimi.
  static void light() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Olumlu sonuç: öğün kaydedildi, su eklendi, set bitti.
  static void success() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Önemli olay: antrenman bitti, hedef tamamlandı.
  static void celebrate() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 140), HapticFeedback.mediumImpact);
  }

  /// Uyarı / silme.
  static void warning() {
    if (enabled) HapticFeedback.vibrate();
  }
}
