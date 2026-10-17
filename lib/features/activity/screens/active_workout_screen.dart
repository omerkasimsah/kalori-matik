import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/exercise_media.dart';

/// Antrenmandaki tek bir adım (egzersiz veya dinlenme).
class WorkoutStep {
  final String name;

  /// Süreli adımlar için saniye; null ise tekrar bazlıdır ve elle geçilir.
  final int? durationSec;
  final int? sets;
  final int? reps;
  final bool isRest;
  final String? notes;

  /// Kütüphanedeki egzersiz kimliği (görsel/animasyon için).
  final String? exerciseId;

  const WorkoutStep({
    required this.name,
    this.durationSec,
    this.sets,
    this.reps,
    this.isRest = false,
    this.notes,
    this.exerciseId,
  });

  const WorkoutStep.rest(int seconds)
      : name = 'Dinlen',
        durationSec = seconds,
        sets = null,
        reps = null,
        isRest = true,
        notes = null,
        exerciseId = null;
}

/// Ekipmansız, 10 dakikalık varsayılan tüm vücut antrenmanı.
const List<WorkoutStep> quickFullBodyWorkout = [
  WorkoutStep(name: 'Jumping Jacks', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Squat', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Şınav', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Mountain Climber', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Lunge', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Plank', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'High Knees', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Glute Bridge', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Burpee', durationSec: 40),
  WorkoutStep.rest(20),
  WorkoutStep(name: 'Bicycle Crunch', durationSec: 40),
];

class ActiveWorkoutScreen extends StatefulWidget {
  final String title;
  final List<WorkoutStep> steps;

  /// Bitişte yakılan kaloriyi göstermek için (MET ve kilo).
  final double met;
  final double weightKg;

  const ActiveWorkoutScreen({
    super.key,
    this.title = 'Hızlı Tüm Vücut',
    this.steps = quickFullBodyWorkout,
    this.met = 5.0,
    this.weightKg = 70,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  int _index = 0;
  int _remaining = 0;
  bool _isPlaying = true;
  bool _finished = false;
  Timer? _timer;
  final Stopwatch _elapsed = Stopwatch();

  WorkoutStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    _elapsed.start();
    _startStep(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStep(int index) {
    _timer?.cancel();
    setState(() {
      _index = index;
      _remaining = widget.steps[index].durationSec ?? 0;
    });
    if (_step.durationSec != null && _isPlaying) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        Haptics.success();
        _next();
      } else {
        setState(() => _remaining--);
        if (_remaining <= 3) Haptics.light();
      }
    });
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _elapsed.start();
      if (_step.durationSec != null) _startTimer();
    } else {
      _elapsed.stop();
      _timer?.cancel();
    }
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      _finish();
    } else {
      _startStep(_index + 1);
    }
  }

  void _previous() {
    if (_index > 0) _startStep(_index - 1);
  }

  void _finish() {
    _timer?.cancel();
    _elapsed.stop();
    Haptics.celebrate();
    setState(() => _finished = true);
  }

  Future<bool> _confirmExit() async {
    if (_finished) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Antrenmandan çıkılsın mı?'),
        content: const Text('İlerlemen kaydedilmeyecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Devam et')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Çık',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    return ok ?? false;
  }

  String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmExit()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close, size: 28),
            onPressed: () async {
              final navigator = Navigator.of(context);
              if (await _confirmExit()) navigator.pop();
            },
          ),
        ),
        body: SafeArea(child: _finished ? _buildFinished() : _buildActive()),
      ),
    );
  }

  Widget _buildActive() {
    final step = _step;
    final total = step.durationSec;
    final progress =
        total != null && total > 0 ? 1 - (_remaining / total) : null;
    final color = step.isRest ? AppColors.secondary : AppColors.primary;
    final upcoming = widget.steps
        .skip(_index + 1)
        .firstWhere((s) => !s.isRest, orElse: () => const WorkoutStep(name: ''));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_index + 1) / widget.steps.length,
            minHeight: 6,
            backgroundColor: AppColors.cardSurface,
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text('${_index + 1} / ${widget.steps.length}',
              style: TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress ?? 1,
                  strokeWidth: 14,
                  backgroundColor: AppColors.cardSurface,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: total != null
                      ? Text(
                          _fmt(_remaining),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${step.reps ?? '-'}',
                              style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: color),
                            ),
                            Text('tekrar',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                ),
              ],
            ),
          ),
          if (step.exerciseId != null && hasExerciseMedia(step.exerciseId!)) ...[
            const SizedBox(height: 20),
            ExerciseAnimation(exerciseId: step.exerciseId!, height: 170),
          ],
          const SizedBox(height: 24),
          Text(
            step.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          if (step.notes != null && step.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(step.notes!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          ],
          if (upcoming.name.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Sıradaki: ${upcoming.name}',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Önceki',
                icon: const Icon(Icons.skip_previous_rounded),
                color: AppColors.textSecondary,
                iconSize: 48,
                onPressed: _index > 0 ? _previous : null,
              ),
              const SizedBox(width: 24),
              if (step.durationSec != null)
                _RoundButton(
                  icon: _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  onTap: _togglePlay,
                )
              else
                _RoundButton(icon: Icons.check_rounded, onTap: _next),
              const SizedBox(width: 24),
              IconButton(
                tooltip: 'Sonraki',
                icon: const Icon(Icons.skip_next_rounded),
                color: AppColors.textSecondary,
                iconSize: 48,
                onPressed: _next,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFinished() {
    final minutes = (_elapsed.elapsed.inSeconds / 60).ceil();
    final exercises = widget.steps.where((s) => !s.isRest).length;
    final kcal = (widget.met * widget.weightKg * minutes / 60).round();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.emoji_events_rounded,
              size: 96, color: AppColors.carbs),
          const SizedBox(height: 24),
          Text('Harika iş! 💪',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Text('$exercises egzersizi $minutes dakikada tamamladın.\n≈ $kcal kcal yaktın 🔥',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 40),
          ElevatedButton(
            // Süre (dk) sonuç olarak döner; Aktivite ekranı bunu kaydeder.
            onPressed: () => Navigator.of(context).pop(minutes < 1 ? 1 : minutes),
            child: const Text('Kaydet ve Bitir'),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(50),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Icon(icon, color: AppColors.background, size: 40),
      ),
    );
  }
}
