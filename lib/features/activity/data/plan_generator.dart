import 'package:flutter/material.dart';

import 'exercise_library.dart';
import 'workout_programs.dart';

enum PlanGoal {
  muscle('Kas Kazanımı', Icons.fitness_center),
  fatLoss('Yağ Yakımı', Icons.local_fire_department_outlined),
  health('Genel Sağlık', Icons.favorite_border);

  final String label;
  final IconData icon;
  const PlanGoal(this.label, this.icon);
}

enum PlanPlace {
  home('Evde'),
  gym('Salonda');

  final String label;
  const PlanPlace(this.label);
}

/// Kullanıcının program tercihleri.
class PlanRequest {
  final PlanGoal goal;
  final PlanPlace place;
  final int daysPerWeek; // 2–6
  final int minutes; // seans süresi: 20 / 30 / 45 / 60
  final Level level;

  const PlanRequest({
    required this.goal,
    required this.place,
    required this.daysPerWeek,
    required this.minutes,
    required this.level,
  });

  Map<String, dynamic> toJson() => {
        'goal': goal.name,
        'place': place.name,
        'days': daysPerWeek,
        'minutes': minutes,
        'level': level.name,
      };

  factory PlanRequest.fromJson(Map<String, dynamic> j) => PlanRequest(
        goal: PlanGoal.values.byName(j['goal'] as String),
        place: PlanPlace.values.byName(j['place'] as String),
        daysPerWeek: (j['days'] as num).toInt(),
        minutes: (j['minutes'] as num).toInt(),
        level: Level.values.byName(j['level'] as String),
      );
}

/// Haftanın bir antrenman günü (1 = Pazartesi … 7 = Pazar).
class PlanDay {
  final int weekday;
  final WorkoutProgram program;

  const PlanDay({required this.weekday, required this.program});
}

class WeeklyPlan {
  final PlanRequest request;
  final List<PlanDay> days;

  const WeeklyPlan({required this.request, required this.days});

  PlanDay? dayFor(int weekday) {
    for (final d in days) {
      if (d.weekday == weekday) return d;
    }
    return null;
  }

  /// Bugünden sonraki ilk antrenman günü (bugün dahil).
  PlanDay? nextFrom(int weekday) {
    for (var i = 0; i < 7; i++) {
      final d = dayFor(((weekday - 1 + i) % 7) + 1);
      if (d != null) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'request': request.toJson(),
        'days': [
          for (final d in days)
            {
              'weekday': d.weekday,
              'title': d.program.title,
              'subtitle': d.program.subtitle,
              'category': d.program.category.name,
              'level': d.program.level.name,
              'met': d.program.met,
              'items': [
                for (final i in d.program.items)
                  {
                    'id': i.exerciseId,
                    'sets': i.sets,
                    'reps': i.reps,
                    'dur': i.durationSec,
                    'rest': i.restSec,
                  }
              ],
            }
        ],
      };

  factory WeeklyPlan.fromJson(Map<String, dynamic> j) {
    final days = <PlanDay>[];
    for (final raw in (j['days'] as List)) {
      final d = Map<String, dynamic>.from(raw as Map);
      final weekday = (d['weekday'] as num).toInt();
      final items = <ProgramItem>[];
      for (final r in (d['items'] as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        // Kütüphaneden kaldırılmış bir egzersiz varsa atla.
        if (!exercisesById.containsKey(m['id'])) continue;
        items.add(ProgramItem(
          m['id'] as String,
          sets: (m['sets'] as num?)?.toInt(),
          reps: (m['reps'] as num?)?.toInt(),
          durationSec: (m['dur'] as num?)?.toInt(),
          restSec: (m['rest'] as num?)?.toInt(),
        ));
      }
      if (items.isEmpty) continue;
      days.add(PlanDay(
        weekday: weekday,
        program: WorkoutProgram(
          id: 'plan_$weekday',
          title: d['title'] as String,
          subtitle: d['subtitle'] as String,
          category: ProgramCategory.values.byName(d['category'] as String),
          level: Level.values.byName(d['level'] as String),
          icon: _iconFor(ProgramCategory.values.byName(d['category'] as String)),
          items: items,
          metOverride: (d['met'] as num?)?.toDouble(),
        ),
      ));
    }
    return WeeklyPlan(
        request: PlanRequest.fromJson(Map<String, dynamic>.from(j['request'] as Map)),
        days: days);
  }
}

IconData _iconFor(ProgramCategory c) => switch (c) {
      ProgramCategory.gym => Icons.fitness_center,
      ProgramCategory.home => Icons.home_rounded,
      ProgramCategory.cardio => Icons.bolt,
      ProgramCategory.flexibility => Icons.self_improvement,
    };

// ── Üretici ──────────────────────────────────────────────────────────────────

enum _Focus {
  full('Tüm Vücut', [Muscle.legs, Muscle.chest, Muscle.back, Muscle.shoulders, Muscle.core]),
  push('İtme', [Muscle.chest, Muscle.shoulders, Muscle.arms]),
  pull('Çekme', [Muscle.back, Muscle.arms, Muscle.core]),
  legs('Bacak', [Muscle.legs, Muscle.core]),
  upper('Üst Vücut', [Muscle.chest, Muscle.back, Muscle.shoulders, Muscle.arms]),
  lower('Alt Vücut', [Muscle.legs, Muscle.core]),
  cardio('Kardiyo & Core', [Muscle.cardio, Muscle.fullBody, Muscle.core]);

  final String label;
  final List<Muscle> muscles;
  const _Focus(this.label, this.muscles);
}

const _stretchIds = {
  'child_pose', 'cat_cow', 'hamstring_stretch', 'hip_flexor', 'shoulder_stretch'
};

class PlanGenerator {
  static const _weekdaysByCount = {
    2: [1, 4],
    3: [1, 3, 5],
    4: [1, 2, 4, 5],
    5: [1, 2, 3, 5, 6],
    6: [1, 2, 3, 4, 5, 6],
  };

  static List<_Focus> _focusFor(int days, PlanGoal goal) {
    switch (days) {
      case 2:
      case 3:
        return List.filled(days, _Focus.full);
      case 4:
        return [_Focus.upper, _Focus.lower, _Focus.upper, _Focus.lower];
      case 5:
        return [
          _Focus.push, _Focus.pull, _Focus.legs, _Focus.full,
          goal == PlanGoal.muscle ? _Focus.upper : _Focus.cardio
        ];
      default:
        return [
          _Focus.push, _Focus.pull, _Focus.legs,
          _Focus.upper, _Focus.lower, _Focus.cardio
        ];
    }
  }

  static WeeklyPlan generate(PlanRequest r) {
    final days = r.daysPerWeek.clamp(2, 6);
    final weekdays = _weekdaysByCount[days]!;
    final focuses = _focusFor(days, r.goal);

    final plan = <PlanDay>[];
    final seen = <_Focus, int>{};
    for (var i = 0; i < days; i++) {
      final focus = focuses[i];
      final round = seen[focus] = (seen[focus] ?? -1) + 1;
      plan.add(PlanDay(
        weekday: weekdays[i],
        program: _buildSession(r, focus, i + 1, round),
      ));
    }
    return WeeklyPlan(request: r, days: plan);
  }

  static WorkoutProgram _buildSession(
      PlanRequest r, _Focus focus, int number, int round) {
    final pool = exerciseLibrary.where((e) {
      if (_stretchIds.contains(e.id)) return false;
      if (e.level.index > r.level.index) return false;
      if (r.place == PlanPlace.home && e.equipment != Equipment.none) {
        return false;
      }
      return true;
    }).toList();

    // Hedefe göre set / tekrar / dinlenme
    final isHome = r.place == PlanPlace.home;
    final (sets, reps, rest) = switch (r.goal) {
      PlanGoal.muscle => isHome
          ? (3, 15, 60)
          : (r.level == Level.beginner ? 3 : 4, 10, 90),
      PlanGoal.fatLoss => (3, 15, 40),
      PlanGoal.health => (3, 12, 60),
    };

    // Her kas grubundan sırayla seç; aynı odaklı seanslar farklı hareketler alsın.
    final queues = <Muscle, List<Exercise>>{};
    for (final m in focus.muscles) {
      final list = pool.where((e) => e.muscle == m).toList();
      if (list.isEmpty) continue;
      // Seans turuna göre listeyi döndür (deterministik çeşitlilik)
      final shift = round % list.length;
      queues[m] = [...list.sublist(shift), ...list.sublist(0, shift)];
    }

    final budgetSec = (r.minutes * 60 - (r.minutes >= 30 ? 150 : 60));
    var used = 0;
    final items = <ProgramItem>[];
    final chosen = <String>{};

    bool addFrom(Muscle m) {
      final q = queues[m];
      if (q == null) return false;
      while (q.isNotEmpty) {
        final e = q.removeAt(0);
        if (chosen.contains(e.id)) continue;
        final timed = e.isTimed;
        final dur = timed ? e.durationSec : null;
        final itemSets = (e.id == 'treadmill_run' || e.id == 'rowing') ? 1 : sets;
        final work = dur ?? 40;
        final cost = itemSets * (work + (timed && dur! >= 600 ? 0 : rest));
        if (used + cost > budgetSec && items.length >= 3) return false;
        items.add(ProgramItem(
          e.id,
          sets: itemSets,
          reps: timed ? null : reps,
          restSec: (timed && dur! >= 600) ? 0 : rest,
        ));
        chosen.add(e.id);
        used += cost;
        return true;
      }
      return false;
    }

    // Round-robin: tüm gruplar tükenene ya da süre dolana kadar
    var progressed = true;
    while (progressed && items.length < 9) {
      progressed = false;
      for (final m in focus.muscles) {
        if (items.length >= 9) break;
        if (addFrom(m)) progressed = true;
      }
      if (used >= budgetSec && items.length >= 3) break;
    }

    // Yağ yakımı hedefinde seans sonuna kısa HIIT bitirişi
    if (r.goal == PlanGoal.fatLoss &&
        focus != _Focus.cardio &&
        r.minutes >= 30) {
      for (final id in ['mountain_climber', 'jumping_jacks']) {
        if (chosen.contains(id)) continue;
        final e = exerciseById(id);
        if (e.level.index > r.level.index) continue;
        items.add(ProgramItem(id, sets: 2, restSec: 20));
        break;
      }
    }

    // Soğuma: ≥30 dk seanslarda 2 esneme hareketi
    if (r.minutes >= 30) {
      final cooldown = focus == _Focus.legs || focus == _Focus.lower
          ? ['hamstring_stretch', 'hip_flexor']
          : ['shoulder_stretch', 'child_pose'];
      for (final id in cooldown) {
        items.add(ProgramItem(id, sets: 1, restSec: 10));
      }
    }

    final category = focus == _Focus.cardio
        ? ProgramCategory.cardio
        : (isHome ? ProgramCategory.home : ProgramCategory.gym);
    final met = switch (r.goal) {
      PlanGoal.muscle => isHome ? 4.5 : 5.0,
      PlanGoal.fatLoss => isHome ? 5.5 : 6.0,
      PlanGoal.health => isHome ? 4.0 : 4.5,
    };

    return WorkoutProgram(
      id: 'plan_$number',
      title: 'Gün $number · ${focus.label}',
      subtitle: '${r.goal.label} • ${r.place.label}',
      category: category,
      level: r.level,
      icon: _iconFor(category),
      items: items,
      metOverride: focus == _Focus.cardio ? met + 1.5 : met,
    );
  }
}
