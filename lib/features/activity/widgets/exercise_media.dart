import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Görseli bulunan egzersizler (assets/exercises/<id>/0.jpg ve 1.jpg).
/// Görseller açık kaynaklı free-exercise-db'den alınmıştır (Unlicense / kamu malı).
const Set<String> exercisesWithMedia = {'back_squat','bench_press','bent_row','bicep_curl','bicycle_crunch','cable_fly','calf_raise','cat_cow','child_pose','crunch','db_press','db_row','glute_bridge','hammer_curl','hamstring_stretch','hip_flexor','incline_db_press','jump_squat','jumping_jacks','lat_pulldown','lateral_raise','leg_press','leg_raise','lunge','mountain_climber','plank','pullup','pushup','rdl','rowing','russian_twist','seated_row','shoulder_press','shoulder_stretch','squat','superman','treadmill_run','tricep_dips','tricep_pushdown'};

bool hasExerciseMedia(String id) => exercisesWithMedia.contains(id);

String _frame(String id, int i) => 'assets/exercises/$id/$i.jpg';

/// Başlangıç ve bitiş pozisyonu karelerini yumuşak geçişle döndüren animasyon.
class ExerciseAnimation extends StatefulWidget {
  final String exerciseId;
  final double height;
  final bool animate;

  const ExerciseAnimation({
    super.key,
    required this.exerciseId,
    this.height = 220,
    this.animate = true,
  });

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation> {
  Timer? _timer;
  bool _second = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        if (mounted) setState(() => _second = !_second);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!hasExerciseMedia(widget.exerciseId)) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: widget.height,
        width: double.infinity,
        // Fotoğraflar açık zeminlidir; her iki temada da beyaz çerçeve.
        color: Colors.white,
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 500),
          crossFadeState:
              _second ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: _img(0),
          secondChild: _img(1),
        ),
      ),
    );
  }

  Widget _img(int i) => Image.asset(
        _frame(widget.exerciseId, i),
        height: widget.height,
        width: double.infinity,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.fitness_center, color: AppColors.textHint),
        ),
      );
}

/// Liste için küçük kare önizleme (ilk kare).
class ExerciseThumb extends StatelessWidget {
  final String exerciseId;
  final double size;
  final IconData fallback;

  const ExerciseThumb({
    super.key,
    required this.exerciseId,
    required this.fallback,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: size,
        height: size,
        color: hasExerciseMedia(exerciseId) ? Colors.white : AppColors.surface,
        child: hasExerciseMedia(exerciseId)
            ? Image.asset(_frame(exerciseId, 0), fit: BoxFit.cover)
            : Icon(fallback, color: AppColors.textSecondary),
      ),
    );
  }
}
