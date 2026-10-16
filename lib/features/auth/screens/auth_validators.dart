/// Giriş ve kayıt formları için ortak doğrulayıcılar.
class AuthValidators {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'E-posta adresinizi girin';
    if (!_emailRegex.hasMatch(v)) return 'Geçerli bir e-posta adresi girin';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Şifre belirleyin';
    if (v.length < 6) return 'Şifre en az 6 karakter olmalı';
    return null;
  }
}
