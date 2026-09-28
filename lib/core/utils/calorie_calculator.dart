// Mifflin-St Jeor Formülü Kullanılarak Kalori Hesaplama Aracı
class CalorieCalculator {
  /// Bazal Metabolizma Hızını (BMR) Hesaplar
  /// [weight] kg cinsinden ağırlık, [height] cm cinsinden boy, [age] yıl cinsinden yaş
  /// [isMale] true ise Erkek, false ise Kadın hesaplaması uygulanır.
  static int calculateBMR({
    required double weight,
    required double height,
    required int age,
    required bool isMale,
  }) {
    double bmr;
    if (isMale) {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }
    return bmr.round();
  }

  /// Toplam Günlük Enerji Harcamasını (TDEE - Total Daily Energy Expenditure) Hesaplar
  /// [activityLevel] kullanıcının hayat tarzına (hareketliliğine) bağlı katsayıdır:
  /// Hareketsiz: 1.2, Hafif Aktif: 1.375, Orta Aktif: 1.55, Aktif: 1.725, Çok Aktif: 1.9
  static int calculateTDEE({
    required int bmr,
    required double activityLevel,
  }) {
    return (bmr * activityLevel).round();
  }

  /// Kullanıcının ana hedefine ('lose', 'maintain', 'gain') bağlı olarak günlük alınması gereken kalori miktarını hesaplar.
  /// [tdee] hesaplanmış olan TDEE (Günlük harcama)
  /// [goal] kullanıcının belirlediği amaç (Kilo Ver, Kilo Koru, Kilo Al)
  static int calculateDailyTarget({
    required int tdee,
    required String goal,
  }) {
    switch (goal.toLowerCase()) {
      case 'lose':
        return tdee - 500; // Kalori açığı oluşturma (-500 kcal)
      case 'gain':
        return tdee + 500; // Kalori fazlası oluşturma (+500 kcal)
      case 'maintain':
      default:
        return tdee;
    }
  }

  /// Calculates daily calorie target based on weight loss goal.
  ///
  /// [tdee]              — kullanıcının TDEE değeri (kcal/gün)
  /// [targetWeightLoss]  — vermek istenen kilo (kg)
  /// [days]              — hedef süre (gün)
  ///
  /// 1 kg yağ ≈ 7700 kcal. Güvenli üst sınır: 1000 kcal/gün açık.
  /// Dönen değer: günlük alınması önerilen kalori miktarı.
  static int calculateWeightLossCalorie({
    required int tdee,
    required double targetWeightLoss,
    required int days,
  }) {
    if (days <= 0 || targetWeightLoss <= 0) return tdee;
    const double kcalPerKg = 7700.0;
    final double rawDeficit = (targetWeightLoss * kcalPerKg) / days;
    // Sağlıklı limit: maksimum 1000 kcal/gün açık
    final double deficit = rawDeficit.clamp(0.0, 1000.0);
    final int result = (tdee - deficit).round();
    // Minimum 1200 kcal (sağlıklı alt sınır)
    return result < 1200 ? 1200 : result;
  }

  /// Verilen TDEE ve hedef kilo kaybı için tahmini kaç gün süreceğini döner.
  /// [dailyDeficit] günlük kalori açığı (kcal)
  static int estimateDays({
    required double targetWeightLoss,
    required int dailyDeficit,
  }) {
    if (dailyDeficit <= 0 || targetWeightLoss <= 0) return 0;
    const double kcalPerKg = 7700.0;
    return ((targetWeightLoss * kcalPerKg) / dailyDeficit).ceil();
  }
}
