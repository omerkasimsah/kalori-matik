import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_matik/features/activity/data/exercise_library.dart';
import 'package:kalori_matik/features/activity/data/plan_generator.dart';
import 'package:kalori_matik/features/activity/data/workout_programs.dart';

PlanRequest req({
  PlanGoal goal = PlanGoal.fatLoss,
  PlanPlace place = PlanPlace.home,
  int days = 3,
  int minutes = 30,
  Level level = Level.beginner,
}) =>
    PlanRequest(goal: goal, place: place, daysPerWeek: days, minutes: minutes, level: level);

void main() {
  test('gün sayısı kadar seans üretir, günler artan ve geçerli', () {
    for (var d = 2; d <= 6; d++) {
      final plan = PlanGenerator.generate(req(days: d));
      expect(plan.days.length, d);
      final wd = plan.days.map((e) => e.weekday).toList();
      expect(wd.toSet().length, d);
      expect(wd, orderedEquals([...wd]..sort()));
      expect(wd.every((x) => x >= 1 && x <= 7), isTrue);
    }
  });

  test('evde planında yalnızca ekipmansız hareket olur', () {
    final plan = PlanGenerator.generate(req(place: PlanPlace.home, days: 5, minutes: 45));
    for (final d in plan.days) {
      for (final i in d.program.items) {
        expect(i.exercise.equipment, Equipment.none, reason: i.exerciseId);
      }
    }
  });

  test('başlangıç seviyesinde ileri hareket yok', () {
    final plan = PlanGenerator.generate(
        req(place: PlanPlace.gym, level: Level.beginner, days: 6, minutes: 60));
    for (final d in plan.days) {
      for (final i in d.program.items) {
        expect(i.exercise.level.index, lessThanOrEqualTo(Level.beginner.index),
            reason: i.exerciseId);
      }
    }
  });

  test('süre bütçesine saygı gösterir', () {
    for (final m in [20, 30, 45, 60]) {
      final plan = PlanGenerator.generate(
          req(place: PlanPlace.gym, level: Level.intermediate, minutes: m, days: 4));
      for (final d in plan.days) {
        // Isınma/soğuma payı ve yuvarlama için %35 tolerans
        expect(d.program.estimatedMinutes, lessThanOrEqualTo((m * 1.35).ceil()),
            reason: '${d.program.title} $m dk');
        expect(d.program.items.length, greaterThanOrEqualTo(3));
      }
    }
  });

  test('aynı odaklı seanslar farklı hareketler içerir', () {
    final plan = PlanGenerator.generate(req(days: 3, place: PlanPlace.home, minutes: 30));
    final a = plan.days[0].program.items.map((e) => e.exerciseId).toList();
    final b = plan.days[1].program.items.map((e) => e.exerciseId).toList();
    expect(a, isNot(equals(b)));
  });

  test('yağ yakımı seansı kas planından daha yüksek MET taşır', () {
    final fat = PlanGenerator.generate(req(goal: PlanGoal.fatLoss, place: PlanPlace.gym));
    final muscle = PlanGenerator.generate(req(goal: PlanGoal.muscle, place: PlanPlace.gym));
    expect(fat.days.first.program.met, greaterThan(muscle.days.first.program.met));
  });

  test('JSON gidiş-dönüşte plan aynı kalır', () {
    final plan = PlanGenerator.generate(req(days: 4, place: PlanPlace.gym, level: Level.intermediate));
    final copy = WeeklyPlan.fromJson(plan.toJson());
    expect(copy.days.length, plan.days.length);
    for (var i = 0; i < plan.days.length; i++) {
      expect(copy.days[i].weekday, plan.days[i].weekday);
      expect(copy.days[i].program.title, plan.days[i].program.title);
      expect(copy.days[i].program.items.map((e) => e.exerciseId),
          orderedEquals(plan.days[i].program.items.map((e) => e.exerciseId)));
      expect(copy.days[i].program.met, plan.days[i].program.met);
    }
  });

  test('sıradaki antrenman günü bulunur', () {
    final plan = PlanGenerator.generate(req(days: 3)); // Pt, Çar, Cum
    expect(plan.nextFrom(1)!.weekday, 1);
    expect(plan.nextFrom(2)!.weekday, 3);
    expect(plan.nextFrom(6)!.weekday, 1); // hafta sonu → Pazartesi
  });

  test('program kalorisi MET × kilo × süre', () {
    final p = workoutPrograms.firstWhere((p) => p.id == 'hiit_15');
    expect(p.met, 8.5);
    expect(p.caloriesFor(70), (8.5 * 70 * p.estimatedMinutes / 60).round());
  });
}
