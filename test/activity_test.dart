import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_matik/features/activity/data/exercise_library.dart';
import 'package:kalori_matik/features/activity/data/sports.dart';
import 'package:kalori_matik/features/activity/data/workout_programs.dart';

void main() {
  test('egzersiz kimlikleri benzersiz ve her egzersizin adımı var', () {
    final ids = exerciseLibrary.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final e in exerciseLibrary) {
      expect(e.steps, isNotEmpty, reason: e.id);
      expect(e.sets, greaterThan(0), reason: e.id);
    }
  });

  test('tüm program kalemleri kütüphanede bulunuyor', () {
    for (final p in workoutPrograms) {
      expect(p.items, isNotEmpty, reason: p.id);
      for (final i in p.items) {
        expect(() => i.exercise, returnsNormally, reason: '${p.id}/${i.exerciseId}');
      }
    }
  });

  test('program adımlara açılır: setler ayrı, aralarda dinlenme, sonda dinlenme yok', () {
    final p = workoutPrograms.firstWhere((p) => p.id == 'home_full');
    final steps = p.toSteps();
    expect(steps.first.isRest, isFalse);
    expect(steps.last.isRest, isFalse);
    final work = steps.where((s) => !s.isRest).length;
    final expected = p.items.fold<int>(0, (s, i) => s + i.effectiveSets);
    expect(work, expected);
    // Çalışma adımları arasında dinlenme olmalı
    expect(steps.where((s) => s.isRest).length, greaterThanOrEqualTo(work - 1 - 2));
  });

  test('süreli egzersiz süre, tekrarlı egzersiz tekrar taşır', () {
    final steps = workoutPrograms.firstWhere((p) => p.id == 'home_core').toSteps();
    final plank = steps.firstWhere((s) => s.name.startsWith('Plank'));
    expect(plank.durationSec, 40);
    final twist = steps.firstWhere((s) => s.name.startsWith('Bicycle'));
    expect(twist.durationSec, isNull);
    expect(twist.reps, 20);
  });

  test('tahmini süre makul', () {
    for (final p in workoutPrograms) {
      expect(p.estimatedMinutes, inInclusiveRange(5, 90), reason: p.id);
    }
  });

  test('MET ile kalori hesabı', () {
    final run = sportById('run');
    // 9.8 × 70 kg × 0.5 saat = 343
    expect(run.caloriesFor(minutes: 30, weightKg: 70), 343);
    expect(run.caloriesFor(minutes: 0, weightKg: 70), 0);
    expect(sportById('bilinmeyen').id, 'other');
  });
}
