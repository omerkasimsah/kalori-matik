// Öğün Kaydı Veri Modeli (Data Transfer Object - DTO)
// Supabase 'meal_logs' tablosu ve Riverpod State yönetimi arasındaki temel arayüz birimidir.
class MealLog {
  final String id;          // Kaydın eşsiz tanımlayıcısı
  final String name;        // Yemeğin Adı
  final int calories;       // Toplam Kalori Değeri
  final DateTime createdAt; // Kaydın oluşturulma zamanı (yerel saat)

  // ── Yapay Zeka (Gemini API) Zenginleştirilmiş Verileri ──
  final String? insight;  // Yapay zekanın yemekle ilgili çıkardığı kısa motivasyon/besin notu
  final double? protein;  // Protein miktarı (gram)
  final double? carbs;    // Karbonhidrat miktarı (gram)
  final double? fat;      // Yağ miktarı (gram)

  const MealLog({
    required this.id,
    required this.name,
    required this.calories,
    required this.createdAt,
    this.insight,
    this.protein,
    this.carbs,
    this.fat,
  });

  /// Öğün Zamanı (Format: HH:mm)
  String get time =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  /// Yerel saate göre gün anahtarı (gruplama için).
  DateTime get day => DateTime(createdAt.year, createdAt.month, createdAt.day);

  factory MealLog.fromMap(Map<String, dynamic> map) {
    return MealLog(
      id: map['id'].toString(),
      name: (map['name'] as String?) ?? 'Bilinmeyen',
      calories: _toInt(map['calories']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      insight: map['insight'] as String?,
      protein: _toDouble(map['protein']),
      carbs: _toDouble(map['carbs']),
      fat: _toDouble(map['fat']),
    );
  }

  MealLog copyWith({
    String? id,
    String? name,
    int? calories,
    DateTime? createdAt,
    String? insight,
    double? protein,
    double? carbs,
    double? fat,
  }) {
    return MealLog(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      createdAt: createdAt ?? this.createdAt,
      insight: insight ?? this.insight,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
