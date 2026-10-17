# Google Play Mağaza Hazırlık Rehberi

Bu dosya Play Console'da doldurman gereken metinleri ve formlarda verilecek cevapların taslağını içerir. Mağazada yayınlanmadan önce hepsini gözden geçir; hukuki konularda uzmana danış.

## Uygulama bilgileri
- **Uygulama adı:** KaloriMatik – Kalori & Antrenman
- **Paket adı:** `com.omerkasimsah.kalorimatik` (yayından sonra değiştirilemez)
- **Kategori:** Sağlık ve Fitness
- **Fiyat:** Ücretsiz
- **Hedef kitle:** 18+

### Kısa açıklama (80 karakter)
Fotoğrafla kalori say, hedefini takip et, antrenmanını planla.

### Tam açıklama
KaloriMatik; kalori, makro, su, kilo ve antrenmanını tek yerde takip etmeni sağlar.

📸 **Fotoğrafla kalori:** Tabağının fotoğrafını çek, yapay zeka tahmini kalori ve makroları çıkarsın. Porsiyonu ayarla, değerleri düzenle.
🎯 **Kişisel hedef:** Boy, kilo, yaş ve hedefine göre günlük kalori ve makro hedefi.
🏋️ **Antrenman merkezi:** 40 egzersizlik kütüphane, hazır programlar ve sana özel haftalık program oluşturucu. Yakılan kalori günlük bütçene eklenir.
📊 **İstatistikler:** Haftalık ve aylık kalori grafikleri, kilo takibi, kayıt serisi.
💧 **Su ve adım takibi**, isteğe bağlı hatırlatıcılar.
🧑‍⚕️ **Koç / diyetisyen modu:** Danışanlarını takip et, öğünlerine yorum yap, plan ve not ekle. Danışanlar veri paylaşımını onaylar ve istedikleri zaman kaldırır.
🌓 Açık ve koyu tema.

⚠️ KaloriMatik tıbbi tavsiye vermez. Kalori ve antrenman değerleri tahminidir; sağlık sorunun varsa programa başlamadan önce doktoruna danış.

## Ekran görüntüleri (öneri sırası)
Demo modu ile alınabilir: `flutter run -d chrome --dart-define=DEMO_MODE=client` (mobil boyutta).
1. Ana sayfa (kalori halkası)  2. Fotoğraf analizi sonucu  3. Aktivite / haftalık program  4. Egzersiz detayı (animasyon)  5. İstatistikler  6. Koç paneli (`DEMO_MODE=coach`)

## Veri güvenliği formu (taslak cevaplar)
| Veri türü | Toplanıyor mu | Paylaşılıyor mu | Amaç |
|---|---|---|---|
| E-posta, ad | Evet | Hayır (koç onayıyla ad paylaşılır) | Hesap yönetimi |
| Sağlık bilgileri (kilo, boy, öğünler) | Evet | Yalnızca kullanıcının onayladığı koç/diyetisyenle | Uygulama işlevi |
| Fotoğraflar | Evet (analiz için gönderilir, saklanmaz) | Evet – yapay zeka servisi (Google) | Uygulama işlevi |
| Çökme günlükleri | Evet (Sentry etkinse) | Evet – hata takip servisi | Analitik / hata ayıklama |
- Veriler aktarım sırasında şifrelenir: **Evet**
- Kullanıcı veri silme talep edebilir: **Evet** (uygulama içi + e-posta)
- Hesap silme web adresi: gizlilik politikasındaki "Hesap ve veri silme" bölümünü gösteren sayfa

## Sağlık uygulaması beyanı
Play Console → Uygulama içeriği → "Sağlık uygulamaları" formu: uygulama **beslenme ve fitness takibi** kategorisindedir; tıbbi cihaz değildir, teşhis veya tedavi sunmaz.

## İçerik derecelendirmesi
Anket sonucu büyük olasılıkla herkese uygun; "kullanıcıların etkileşimi" sorusunda koç–danışan notlarını belirt.

## Yayın öncesi kontrol listesi
- [ ] `supabase_phase3`–`phase6` SQL dosyaları çalıştırıldı
- [ ] Edge Function `analyze-food` deploy edildi, GEMINI_API_KEY secret'ı tanımlı
- [ ] Supabase → Auth → URL Configuration → Redirect URL: `kalorimatik://auth-callback`
- [ ] Özel SMTP (Resend vb.) bağlandı; "Confirm email" açık
- [ ] Supabase Pro plan, AB bölgesi, Advisor güvenlik taraması temiz
- [ ] İmza anahtarı oluşturuldu (`android/key.properties.example`), `flutter build appbundle --release`
- [ ] Sentry DSN (isteğe bağlı): `--dart-define=SENTRY_DSN=...`
- [ ] Gizlilik politikası ve kullanım şartları web sayfası olarak yayınlandı (örn. GitHub Pages)
- [ ] 12 test kullanıcısıyla 14 gün kapalı test (yeni kişisel hesaplar için)
- [ ] Gerçek cihazda iki hesapla (danışan + koç) uçtan uca test
