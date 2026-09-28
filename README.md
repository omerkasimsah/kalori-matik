# 🥗 KaloriMatik — AI-Powered Nutrition & Macro Tracker

> **Akıllı besin takibi, yapay zeka destekli tabak analizi ve diyetisyen koçluk modülü.**  
> Built with **Flutter**, **Riverpod**, **Supabase**, and **Google Gemini Vision**.

KaloriMatik, günlük besin ve kalori takibini manuel arama listeleriyle vakit kaybetmeden yapabilmek için geliştirilmiş modern bir mobil uygulamadır. Kullanıcı tabağının fotoğrafını çeker; Gemini Vision API tabağı analiz ederek kalori, protein, karbonhidrat ve yağ değerlerini otomatik hesaplar.

---

## ✨ Öne Çıkan Özellikler

- **📸 Görsel ile Yemek Tanıma (AI Vision):** Kameradan veya galeriden yemek fotoğrafı yükleyin; Gemini 2.5 Flash tabağı analiz edip tahmini porsiyon ve makroları anında JSON formatında çıkarsın.
- **🎯 Günlük Kalori & Makro Hedefleri:** Günlük kalori ihtiyacını, protein, karbonhidrat ve yağ dengesini interaktif halkalar ve göstergelerle takip edin.
- **💧 Su Tüketim Takibi:** Hızlı ekleme butonlarıyla gün boyunca içilen su miktarını kaydedin.
- **📊 Geçmiş & İstatistikler:** Haftalık ve aylık beslenme geçmişini, kalori trendlerini grafiklerle inceleyin.
- **🧑‍⚕️ Diyetisyen / Koç Modülü:** Diyetisyenler kendi danışanlarını sisteme ekleyebilir, danışanların öğün günlüklerini gerçek zamanlı görüntüleyebilir ve geri bildirim bırakabilir.
- **🌙 Modern Koyu Tema:** Uzun süreli kullanımlar için göz yormayan özel koyu arayüz tasarımı.

---

## 🛠️ Mimari ve Teknolojiler

Proje **Feature-First (Özellik Odaklı)** temiz bir mimariyle tasarlanmıştır:

```text
lib/
├── core/
│   ├── services/       # Gemini AI servisi, Supabase yardımcıları
│   ├── theme/          # Renk paletleri, tipografi, karanlık tema
│   └── utils/          # Formatlayıcılar, yardımcı fonksiyonlar
├── features/
│   ├── activity/       # Egzersiz ve günlük aktivite takibi
│   ├── auth/           # Supabase Authentication (Giriş / Kayıt)
│   ├── camera/         # Kamera entegrasyonu, yapay zeka analizi & öğün kaydı
│   ├── history/        # Geçmiş kayıtlar ve filtreleme
│   ├── home/           # Dashboard, özet kartları, hızlı ekleme
│   ├── onboarding/     # İlk kurulum, hedef belirleme adımları
│   ├── profile/        # Profil ayarları, BMR ve TDEE hesaplamaları
│   ├── stats/          # Grafikler ve haftalık analizler
│   └── tracking/       # Detaylı öğün listeleri ve su sayacı
└── main.dart           # Giriş noktası, GoRouter rotaları, Supabase init
```

### Kullanılan Teknolojiler
- **Framework:** Flutter 3.x / Dart
- **State Management:** Riverpod (`flutter_riverpod`)
- **Navigation:** `go_router`
- **Backend & Auth:** Supabase (`supabase_flutter`, PostgreSQL, Row-Level Security)
- **AI / LLM:** Google Gemini 2.5 Flash Vision (`generative-language` REST API)

---

## 🚀 Kurulum ve Çalıştırma

### 1. Depoyu Klonlayın
```bash
git clone https://github.com/omerkasimsah/kalori-matik.git
cd kalori-matik
```

### 2. Bağımlılıkları Yükleyin
```bash
flutter pub get
```

### 3. API Anahtarlarını Tanımlayın
Uygulama Supabase ve Gemini Vision servislerini kullanır. Projeyi çalıştırırken kendi Gemini API anahtarınızı `dart-define` ile sağlayabilirsiniz:

```bash
flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

> **Veritabanı Şeması:** Proje kök dizinindeki `supabase_setup.sql` ve `supabase_coach_module.sql` dosyalarını Supabase SQL Editor üzerinden çalıştırarak gerekli tabloları ve RLS politikalarını saniyeler içinde oluşturabilirsiniz.

---

## 📄 Lisans
Bu proje [MIT Lisansı](LICENSE) kapsamında açık kaynak olarak sunulmuştur.
