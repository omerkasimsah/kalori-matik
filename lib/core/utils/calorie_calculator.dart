/// Günlük makro hedefleri (gram).
class MacroTargets {
  final int protein;
  final int carbs;
  final int fat;

  const MacroTargets({
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

// Mifflin-St Jeor Formülü Kullanılarak Kalori Hesaplama Aracı
class CalorieCalculator {
  /// Sağlıklı günlük kalori alt sınırı.
  static const int minDailyCalories = 1200;

  /// 1 kg yağ ≈ 7700 kcal.
  static const double kcalPerKg = 7700.0;

  /// Bazal Metabolizma Hızını (BMR) Hesaplar
  /// [weight] kg cinsinden ağırlık, [height] cm cinsinden boy, [age] yıl cinsinden yaş
  /// [isMale] true ise Erkek, false ise Kadın hesaplaması uygulanır.
  static int calculateBMR({
    required double weight,
    required double height,
    required int age,
    required bool isMale,
  }) {
    final base = (10 * weight) + (6.25 * height) - (5 * age);
    return (isMale ? base + 5 : base - 161).round();
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
  /// Sonuç asla [minDailyCalories] altına inmez.
  static int calculateDailyTarget({
    required int tdee,
    required String goal,
  }) {
    final int target;
    switch (goal.toLowerCase()) {
      case 'lose':
        target = tdee - 500; // Kalori açığı oluşturma (-500 kcal)
        break;
      case 'gain':
        target = tdee + 500; // Kalori fazlası oluşturma (+500 kcal)
        break;
      default:
        target = tdee;
    }
    return target < minDailyCalories ? minDailyCalories : target;
  }

  /// Kilo verme hedefine göre günlük kalori hedefini hesaplar.
  ///
  /// [tdee]              — kullanıcının TDEE değeri (kcal/gün)
  /// [targetWeightLoss]  — vermek istenen kilo (kg)
  /// [days]              — hedef süre (gün)
  ///
  /// Güvenli üst sınır: 1000 kcal/gün açık, alt sınır 1200 kcal.
  static int calculateWeightLossCalorie({
    required int tdee,
    required double targetWeightLoss,
    required int days,
  }) {
    if (days <= 0 || targetWeightLoss <= 0) return tdee;
    final double rawDeficit = (targetWeightLoss * kcalPerKg) / days;
    final double deficit = rawDeficit.clamp(0.0, 1000.0);
    final int result = (tdee - deficit).round();
    return result < minDailyCalories ? minDailyCalories : result;
  }

  /// Verilen günlük açık ile hedef kilo kaybının kaç gün süreceğini döner.
  static int estimateDays({
    required double targetWeightLoss,
    required int dailyDeficit,
  }) {
    if (dailyDeficit <= 0 || targetWeightLoss <= 0) return 0;
    return ((targetWeightLoss * kcalPerKg) / dailyDeficit).ceil();
  }

  /// Profil bilgilerinden günlük kalori hedefini tek noktadan hesaplar.
  /// Onboarding ve profil ekranı aynı mantığı kullanır.
  static int dailyTargetFor({
    required double weight,
    required double height,
    required int age,
    required bool isMale,
    required double activityLevel,
    required String goal,
    double? targetWeightLoss,
    int? targetDays,
  }) {
    final bmr = calculateBMR(
        weight: weight, height: height, age: age, isMale: isMale);
    final tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel);
    if (goal == 'lose' &&
        targetWeightLoss != null &&
        targetWeightLoss > 0 &&
        targetDays != null &&
        targetDays > 0) {
      return calculateWeightLossCalorie(
        tdee: tdee,
        targetWeightLoss: targetWeightLoss,
        days: targetDays,
      );
    }
    return calculateDailyTarget(tdee: tdee, goal: goal);
  }

  /// Kalori hedefi ve amaca göre makro dağılımı.
  /// Kilo verirken proteini yüksek tutar (%30), alırken karbonhidratı artırır.
  static MacroTargets macroTargets({
    required int calories,
    String goal = 'maintain',
  }) {
    final (p, c, f) = switch (goal) {
      'lose' => (0.30, 0.40, 0.30),
      'gain' => (0.25, 0.50, 0.25),
      _ => (0.25, 0.45, 0.30),
    };
    return MacroTargets(
      protein: (calories * p / 4).round(),
      carbs: (calories * c / 4).round(),
      fat: (calories * f / 9).round(),
    );
  }

  /// Adım sayısından yakılan yaklaşık aktif kaloriyi hesaplar.
  /// Ortalama: adım başına ~0.0005 kcal × vücut ağırlığı (kg).
  static int stepsToCalories(int steps, {double weightKg = 70}) {
    if (steps <= 0) return 0;
    return (steps * 0.0005 * weightKg).round();
  }

  /// Vücut ağırlığına göre önerilen günlük su miktarı (ml): 33 ml/kg, 1.5–4 L arası.
  static int waterGoalMl(double? weightKg) {
    if (weightKg == null || weightKg <= 0) return 2500;
    final ml = (weightKg * 33).round();
    return (ml.clamp(1500, 4000) / 50).round() * 50;
  }
}
