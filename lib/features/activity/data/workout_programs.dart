import 'package:flutter/material.dart';

import '../screens/active_workout_screen.dart';
import 'exercise_library.dart';

/// Programdaki tek bir egzersiz kalemi.
class ProgramItem {
  final String exerciseId;
  final int? sets;
  final int? reps;
  final int? durationSec;
  final int? restSec;

  const ProgramItem(this.exerciseId,
      {this.sets, this.reps, this.durationSec, this.restSec});

  Exercise get exercise => exerciseById(exerciseId);
  int get effectiveSets => sets ?? exercise.sets;
  int get effectiveReps => reps ?? exercise.reps;
  int? get effectiveDuration => durationSec ?? exercise.durationSec;
  int get effectiveRest => restSec ?? exercise.restSec;
}

enum ProgramCategory {
  gym('Gym'),
  home('Evde'),
  cardio('Kardiyo'),
  flexibility('Esneme');

  final String label;
  const ProgramCategory(this.label);
}

class WorkoutProgram {
  final String id;
  final String title;
  final String subtitle;
  final ProgramCategory category;
  final Level level;
  final List<Color> gradient;
  final IconData icon;
  final List<ProgramItem> items;

  const WorkoutProgram({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.level,
    required this.gradient,
    required this.icon,
    required this.items,
  });

  Set<Equipment> get equipment =>
      {for (final i in items) i.exercise.equipment}..remove(Equipment.none);

  /// Her egzersiz için set başına yaklaşık süre + dinlenmelerle toplam dakika.
  int get estimatedMinutes {
    var sec = 0;
    for (final i in items) {
      final work = i.effectiveDuration ?? 40;
      sec += i.effectiveSets * (work + i.effectiveRest);
    }
    return (sec / 60).ceil();
  }

  /// Oynatıcı için adımlara açar: her set ayrı, aralarda dinlenme.
  List<WorkoutStep> toSteps() {
    final steps = <WorkoutStep>[];
    for (var n = 0; n < items.length; n++) {
      final item = items[n];
      final ex = item.exercise;
      final sets = item.effectiveSets;
      for (var s = 1; s <= sets; s++) {
        final label = sets > 1 ? '${ex.name} · Set $s/$sets' : ex.name;
        steps.add(WorkoutStep(
          name: label,
          durationSec: item.effectiveDuration,
          sets: 1,
          reps: item.effectiveDuration == null ? item.effectiveReps : null,
          notes: ex.tips.isEmpty ? null : ex.tips.first,
        ));
        final isLast = n == items.length - 1 && s == sets;
        if (!isLast && item.effectiveRest > 0) {
          steps.add(WorkoutStep.rest(item.effectiveRest));
        }
      }
    }
    return steps;
  }
}

const List<WorkoutProgram> workoutPrograms = [
  WorkoutProgram(
    id: 'gym_push',
    title: 'Gym · İtme Günü',
    subtitle: 'Göğüs, omuz ve triceps',
    category: ProgramCategory.gym,
    level: Level.intermediate,
    gradient: [Color(0xFF3D5AF1), Color(0xFF8B5CF6)],
    icon: Icons.fitness_center,
    items: [
      ProgramItem('bench_press'),
      ProgramItem('incline_db_press'),
      ProgramItem('shoulder_press'),
      ProgramItem('lateral_raise'),
      ProgramItem('cable_fly'),
      ProgramItem('tricep_pushdown'),
    ],
  ),
  WorkoutProgram(
    id: 'gym_pull',
    title: 'Gym · Çekme Günü',
    subtitle: 'Sırt ve biceps',
    category: ProgramCategory.gym,
    level: Level.intermediate,
    gradient: [Color(0xFF00B4DB), Color(0xFF0083B0)],
    icon: Icons.fitness_center,
    items: [
      ProgramItem('lat_pulldown'),
      ProgramItem('bent_row'),
      ProgramItem('seated_row'),
      ProgramItem('db_row'),
      ProgramItem('bicep_curl'),
      ProgramItem('hammer_curl'),
    ],
  ),
  WorkoutProgram(
    id: 'gym_legs',
    title: 'Gym · Bacak Günü',
    subtitle: 'Uyluk, kalça ve baldır',
    category: ProgramCategory.gym,
    level: Level.intermediate,
    gradient: [Color(0xFFFF512F), Color(0xFFDD2476)],
    icon: Icons.directions_walk,
    items: [
      ProgramItem('back_squat'),
      ProgramItem('leg_press'),
      ProgramItem('rdl'),
      ProgramItem('lunge'),
      ProgramItem('calf_raise'),
    ],
  ),
  WorkoutProgram(
    id: 'gym_beginner_full',
    title: 'Gym · Yeni Başlayan Tüm Vücut',
    subtitle: 'Makine ve dambılla güvenli başlangıç',
    category: ProgramCategory.gym,
    level: Level.beginner,
    gradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    icon: Icons.accessibility_new,
    items: [
      ProgramItem('leg_press', sets: 3, reps: 12),
      ProgramItem('db_press', sets: 3, reps: 10),
      ProgramItem('lat_pulldown', sets: 3, reps: 12),
      ProgramItem('shoulder_press', sets: 2, reps: 10),
      ProgramItem('plank', sets: 3),
    ],
  ),
  WorkoutProgram(
    id: 'home_full',
    title: 'Evde Tüm Vücut',
    subtitle: 'Ekipmansız, her yerde yapılır',
    category: ProgramCategory.home,
    level: Level.beginner,
    gradient: [Color(0xFF00FF9D), Color(0xFF00B4DB)],
    icon: Icons.home_rounded,
    items: [
      ProgramItem('squat'),
      ProgramItem('pushup'),
      ProgramItem('lunge'),
      ProgramItem('glute_bridge'),
      ProgramItem('tricep_dips'),
      ProgramItem('plank'),
    ],
  ),
  WorkoutProgram(
    id: 'home_core',
    title: 'Karın & Core',
    subtitle: '10 dakikada karın bölgesi',
    category: ProgramCategory.home,
    level: Level.intermediate,
    gradient: [Color(0xFFF7971E), Color(0xFFFFD200)],
    icon: Icons.self_improvement,
    items: [
      ProgramItem('plank'),
      ProgramItem('bicycle_crunch', sets: 3, reps: 20),
      ProgramItem('leg_raise'),
      ProgramItem('russian_twist'),
      ProgramItem('mountain_climber'),
    ],
  ),
  WorkoutProgram(
    id: 'hiit_15',
    title: 'HIIT Yağ Yakım',
    subtitle: 'Yüksek tempo, kısa dinlenme',
    category: ProgramCategory.cardio,
    level: Level.intermediate,
    gradient: [Color(0xFFFF1744), Color(0xFFFF5722)],
    icon: Icons.bolt,
    items: [
      ProgramItem('jumping_jacks', sets: 3),
      ProgramItem('burpee', sets: 3, reps: 10, restSec: 30),
      ProgramItem('jump_squat', sets: 3, reps: 12, restSec: 30),
      ProgramItem('mountain_climber', sets: 3),
      ProgramItem('high_knees', sets: 3),
    ],
  ),
  WorkoutProgram(
    id: 'cardio_machine',
    title: 'Salon Kardiyo',
    subtitle: 'Koşu bandı ve kürek makinesi',
    category: ProgramCategory.cardio,
    level: Level.beginner,
    gradient: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
    icon: Icons.directions_run,
    items: [
      ProgramItem('treadmill_run'),
      ProgramItem('rowing'),
    ],
  ),
  WorkoutProgram(
    id: 'stretch_10',
    title: 'Esneme & Mobilite',
    subtitle: 'Antrenman sonrası veya sabah rutini',
    category: ProgramCategory.flexibility,
    level: Level.beginner,
    gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    icon: Icons.self_improvement,
    items: [
      ProgramItem('cat_cow'),
      ProgramItem('child_pose'),
      ProgramItem('hamstring_stretch', sets: 2),
      ProgramItem('hip_flexor', sets: 2),
      ProgramItem('shoulder_stretch', sets: 2),
    ],
  ),
];
