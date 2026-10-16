# 🥗 KaloriMatik — AI-Powered Nutrition & Macro Tracker

[![CI](https://github.com/omerkasimsah/kalori-matik/actions/workflows/ci.yml/badge.svg)](https://github.com/omerkasimsah/kalori-matik/actions/workflows/ci.yml)

> **Akıllı besin takibi, yapay zeka destekli tabak analizi ve diyetisyen koçluk modülü.**
> Built with **Flutter**, **Riverpod**, **Supabase**, and **Google Gemini Vision**.

KaloriMatik, günlük besin ve kalori takibini manuel arama listeleriyle vakit kaybetmeden yapabilmek için geliştirilmiş modern bir mobil uygulamadır. Kullanıcı tabağının fotoğrafını çeker; Gemini Vision API tabağı analiz ederek kalori, protein, karbonhidrat ve yağ değerlerini otomatik hesaplar.

---

## ✨ Öne Çıkan Özellikler

- **📸 Görsel ile Yemek Tanıma (AI Vision):** Kameradan veya galeriden fotoğraf yükleyin; Gemini tabağı analiz edip porsiyon ve makroları çıkarsın. Sonucu kaydetmeden önce **porsiyonu (0.5x–2x) ayarlayabilir** ve tüm değerleri düzenleyebilirsiniz.
- **✍️ Elle ve Hızlı Ekleme:** Fotoğraf olmadan öğün girin ya da **sık yediklerinizi** tek dokunuşla tekrar ekleyin.
- **✏️ Düzenle / Sil / Geri Al:** Öğüne dokunarak düzenleyin, sola kaydırarak silin; yanlışlıkla silerseniz "Geri al".
- **🎯 Kalori & Makro Hedefleri:** Mifflin-St Jeor ile hesaplanan günlük hedef, hedefe göre protein/karbonhidrat/yağ dağılımı ve canlı ilerleme çubukları.
- **🚶 Adım Sayar & Aktif Kalori:** Adımlar kilonuza göre yakılan kaloriye çevrilir ve günlük bütçenize eklenir.
- **💧 Su Takibi:** Kilonuza göre hesaplanan günlük hedef ve hızlı ekleme butonları.
- **🏋️ Antrenman Zamanlayıcısı:** Ekipmansız 10 dakikalık hızlı antrenman veya koçunuzun atadığı planları adım adım, geri sayımlı uygulayın.
- **📊 İstatistikler & Geçmiş:** 7/30 günlük kalori grafiği, günlük ortalama, hedefte kalınan gün sayısı, kayıt serisi ve gün gün gruplanmış 30 günlük geçmiş.
- **🧑‍⚕️ Diyetisyen / Koç Modülü:** Panel danışanları "ilgi bekliyor / yolunda" durumuna göre sıralar (kayıt girmeyen veya hedefi aşan danışanlar üstte). Danışan detayında 7 günlük kalori, kilo grafiği, öğünlere yorum, beslenme/antrenman planı ve notlar bulunur. Danışan bunları ana sayfada ve **"Koçum"** ekranında görür.
- **🌙 Modern Koyu Tema:** Tüm ekranlarda tutarlı, yüksek kontrastlı koyu arayüz.

---

## 🛠️ Mimari ve Teknolojiler

Proje **Feature-First (Özellik Odaklı)** bir mimariyle tasarlanmıştır:

```text
lib/
├── core/
│   ├── config/         # AppConfig — dart-define ile okunan ayarlar
│   ├── services/       # Gemini AI servisi, Supabase veri katmanı
│   ├── theme/          # Renk paleti, tipografi, koyu tema
│   └── utils/          # Kalori / makro / su hesaplayıcıları
├── features/
│   ├── activity/       # Adım sayar, antrenman zamanlayıcısı
│   ├── auth/           # Giriş, kayıt, şifre sıfırlama
│   ├── camera/         # Fotoğraf analizi, elle ve hızlı öğün ekleme
│   ├── history/        # 30 günlük geçmiş
│   ├── home/           # Dashboard, öğün listesi, makro & su kartları, koç paneli
│   ├── onboarding/     # İlk kurulum, hedef belirleme adımları
│   ├── profile/        # Profil, BMR/TDEE ve hedef ayarları
│   ├── stats/          # Grafikler ve analizler
│   └── tracking/       # Danışanın "Koçum" ekranı
└── main.dart           # Giriş noktası, GoRouter rotaları, Supabase init
```

### Kullanılan Teknolojiler
- **Framework:** Flutter 3.19+ / Dart 3.3+
- **State Management:** Riverpod — oturum değiştiğinde tüm kullanıcı verisi otomatik sıfırlanır
- **Navigation:** `go_router` (oturum korumalı rotalar)
- **Backend & Auth:** Supabase (PostgreSQL, Row-Level Security)
- **AI / LLM:** Google Gemini 2.5 Flash Vision (REST API)

---

## 🚀 Kurulum ve Çalıştırma

### 1. Depoyu Klonlayın
```bash
git clone https://github.com/omerkasimsah/kalori-matik.git
cd kalori-matik
flutter pub get
```

### 2. Veritabanını Hazırlayın
Supabase SQL Editor'de sırasıyla çalıştırın:

1. `supabase_setup.sql` — temel tablolar ve RLS
2. `supabase_phase25.sql` — KaloriID, koç bağlantıları
3. `supabase_coach_module.sql` — antrenman / beslenme planları, koç notları
4. `supabase_phase3.sql` — öğün düzenleme/silme izinleri, KaloriID ile danışan arama fonksiyonu, indeksler
5. `supabase_phase4.sql` — kilo takibi, koçun öğüne yorumu, hesap silme fonksiyonu

### 3. Gemini Anahtarı (Edge Function)
Yayın sürümünde Gemini anahtarı **uygulamanın içinde bulunmaz**; Supabase Edge Function'da saklanır ([supabase/functions/analyze-food](supabase/functions/analyze-food/index.ts)). [Supabase CLI](https://supabase.com/docs/guides/cli) ile bir kez kurun:

```bash
supabase login
supabase link --project-ref <proje-ref>
supabase secrets set GEMINI_API_KEY=<anahtarın>
supabase functions deploy analyze-food
```

Yalnızca giriş yapmış kullanıcılar fonksiyonu çağırabilir. Geliştirme sırasında Edge Function kurmadan denemek için anahtarı doğrudan verebilirsiniz (bu anahtar **yayın derlemesine eklenmemelidir**):

```bash
flutter run --dart-define=GEMINI_API_KEY=ANAHTAR
```

Kendi Supabase projeniz için `SUPABASE_URL` ve `SUPABASE_ANON_KEY` değerlerini de `--dart-define` ile verebilirsiniz. Anahtar yoksa ve fonksiyon kurulu değilse uygulama çalışmaya devam eder; öğünler elle eklenir.

### 4. Demo Modu (hesap ve internet gerektirmez)
Arayüzü sahte verilerle denemek veya ekran görüntüsü almak için:

```bash
flutter run -d chrome --dart-define=DEMO_MODE=client   # danışan
flutter run -d chrome --dart-define=DEMO_MODE=coach    # koç / diyetisyen
```

### 5. Yayın (Google Play)
`android/key.properties.example` dosyasındaki adımlarla imza anahtarı oluşturun, ardından:

```bash
flutter build appbundle --release   # GEMINI_API_KEY VERMEYİN (Edge Function kullanılır)
```

### 6. Testler
```bash
flutter analyze
flutter test
```

---

## 📄 Lisans
Bu proje [MIT Lisansı](LICENSE) kapsamında açık kaynak olarak sunulmuştur.
