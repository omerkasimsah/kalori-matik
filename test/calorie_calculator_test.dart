import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_matik/core/utils/calorie_calculator.dart';

void main() {
  group('BMR / TDEE', () {
    test('Mifflin-St Jeor erkek', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 1780
      expect(
        CalorieCalculator.calculateBMR(
            weight: 80, height: 180, age: 30, isMale: true),
        1780,
      );
    });

    test('Mifflin-St Jeor kadın', () {
      // 10*60 + 6.25*165 - 5*25 - 161 = 1345.25
      expect(
        CalorieCalculator.calculateBMR(
            weight: 60, height: 165, age: 25, isMale: false),
        1345,
      );
    });

    test('TDEE aktivite katsayısıyla çarpılır', () {
      expect(CalorieCalculator.calculateTDEE(bmr: 1780, activityLevel: 1.55),
          2759);
    });
  });

  group('Günlük hedef', () {
    test('hedefe göre ±500', () {
      expect(CalorieCalculator.calculateDailyTarget(tdee: 2500, goal: 'lose'),
          2000);
      expect(CalorieCalculator.calculateDailyTarget(tdee: 2500, goal: 'gain'),
          3000);
      expect(
          CalorieCalculator.calculateDailyTarget(
              tdee: 2500, goal: 'maintain'),
          2500);
    });

    test('1200 kcal altına inmez', () {
      expect(CalorieCalculator.calculateDailyTarget(tdee: 1500, goal: 'lose'),
          1200);
    });

    test('kilo verme hedefinde açık en fazla 1000 kcal', () {
      // 10 kg / 30 gün → 2567 kcal/gün açık → 1000'e sınırlanır
      expect(
        CalorieCalculator.calculateWeightLossCalorie(
            tdee: 2600, targetWeightLoss: 10, days: 30),
        1600,
      );
    });

    test('kilo verme hedefi makul ise tam açık uygulanır', () {
      // 2 kg / 60 gün → 256.67 kcal/gün
      expect(
        CalorieCalculator.calculateWeightLossCalorie(
            tdee: 2400, targetWeightLoss: 2, days: 60),
        2143,
      );
    });

    test('dailyTargetFor kilo hedefi yoksa standart açığı kullanır', () {
      final target = CalorieCalculator.dailyTargetFor(
        weight: 80,
        height: 180,
        age: 30,
        isMale: true,
        activityLevel: 1.2,
        goal: 'lose',
      );
      // BMR 1780 * 1.2 = 2136 - 500 = 1636
      expect(target, 1636);
    });

    test('estimateDays', () {
      expect(
          CalorieCalculator.estimateDays(
              targetWeightLoss: 1, dailyDeficit: 500),
          16);
      expect(
          CalorieCalculator.estimateDays(targetWeightLoss: 1, dailyDeficit: 0),
          0);
    });
  });

  group('Makro, adım ve su', () {
    test('makro hedefleri kaloriden türetilir', () {
      final m = CalorieCalculator.macroTargets(calories: 2000, goal: 'lose');
      expect(m.protein, 150); // %30 / 4
      expect(m.carbs, 200); // %40 / 4
      expect(m.fat, 67); // %30 / 9
    });

    test('adımdan aktif kalori', () {
      expect(CalorieCalculator.stepsToCalories(0), 0);
      expect(CalorieCalculator.stepsToCalories(10000, weightKg: 70), 350);
    });

    test('su hedefi kiloya göre ve sınırlar içinde', () {
      expect(CalorieCalculator.waterGoalMl(null), 2500);
      expect(CalorieCalculator.waterGoalMl(70), 2300);
      expect(CalorieCalculator.waterGoalMl(30), 1500);
      expect(CalorieCalculator.waterGoalMl(200), 4000);
    });
  });
}
