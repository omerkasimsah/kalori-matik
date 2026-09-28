// Öğün Kaydı Veri Modeli (Data Transfer Object - DTO)
// Supabase 'meal_logs' tablosu ve Riverpod State yönetimi arasındaki temel arayüz birimidir.
class MealLog {
  final String id;        // Kaydın eşsiz tanımlayıcısı
  final String name;      // Yemeğin Adı
  final int calories;     // Toplam Kalori Değeri
  final String time;      // Öğün Zamanı (Format: HH:mm)
  
  // ── Yapay Zeka (Gemini API) Zenginleştirilmiş Verileri ──
  final String? insight;  // Yapay zekanın yemekle ilgili çıkardığı kısa motivasyon/besin notu
  final double? protein;  // Protein miktarı (gram)
  final double? carbs;    // Karbonhidrat miktarı (gram)
  final double? fat;      // Yağ miktarı (gram)

  MealLog({
    required this.id,
    required this.name,
    required this.calories,
    required this.time,
    this.insight,
    this.protein,
    this.carbs,
    this.fat,
  });
}
