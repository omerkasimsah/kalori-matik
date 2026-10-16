import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/calorie_provider.dart';
import '../providers/pedometer_provider.dart';
import 'active_workout_screen.dart';

/// Koçun danışana atadığı aktif antrenman planları.
final myWorkoutPlansProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentUserIdProvider);
  try {
    return await SupabaseService.getMyWorkoutPlans();
  } catch (_) {
    return []; // Koç modülü tabloları kurulmamış olabilir
  }
});

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  static List<WorkoutStep> _stepsFromPlan(Map<String, dynamic> plan) {
    final exercises = List<Map<String, dynamic>>.from(
        (plan['workout_exercises'] as List?) ?? const [])
      ..sort((a, b) => ((a['order_index'] as num?) ?? 0)
          .compareTo((b['order_index'] as num?) ?? 0));
    final steps = <WorkoutStep>[];
    for (final e in exercises) {
      steps.add(WorkoutStep(
        name: e['name'] as String? ?? 'Egzersiz',
        durationSec: (e['duration_sec'] as num?)?.toInt(),
        sets: (e['sets'] as num?)?.toInt(),
        reps: (e['reps'] as num?)?.toInt(),
        notes: e['notes'] as String?,
      ));
      final rest = (e['rest_sec'] as num?)?.toInt() ?? 0;
      if (rest > 0 && e != exercises.last) steps.add(WorkoutStep.rest(rest));
    }
    return steps;
  }

  void _start(BuildContext context, String title, List<WorkoutStep> steps) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ActiveWorkoutScreen(title: title, steps: steps),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(myWorkoutPlansProvider).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(myWorkoutPlansProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: Text(
                'Aktivite',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              sliver: SliverToBoxAdapter(child: _StepsCard()),
            ),
            if (plans.isNotEmpty) ...[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
                sliver: SliverToBoxAdapter(
                  child: Text('KOÇUNUN PLANLARI',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final plan = plans[i];
                      final steps = _stepsFromPlan(plan);
                      final count = steps.where((s) => !s.isRest).length;
                      final title = plan['title'] as String? ?? 'Antrenman';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(18),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.surface,
                              child: Icon(Icons.fitness_center,
                                  color: AppColors.primary),
                            ),
                            title: Text(title,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              [
                                if (plan['week_day'] != null) plan['week_day'],
                                '$count egzersiz',
                              ].join(' • '),
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                            trailing: const Icon(Icons.play_circle_fill,
                                color: AppColors.primary, size: 36),
                            onTap: count == 0
                                ? null
                                : () => _start(context, title, steps),
                          ),
                        ),
                      );
                    },
                    childCount: plans.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
            ],
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _QuickWorkoutCard(
                  onStart: () => _start(
                      context, 'Hızlı Tüm Vücut', quickFullBodyWorkout),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

class _StepsCard extends ConsumerWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedometer = ref.watch(pedometerProvider);
    final active = ref.watch(activeCaloriesProvider);
    final steps = pedometer.steps;
    final progress = (steps / dailyStepGoal).clamp(0.0, 1.0);
    final km = steps * 0.00075;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: !pedometer.isAvailable
          ? Column(
              children: [
                const Icon(Icons.directions_walk,
                    size: 40, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                const Text(
                  'Adım sayar kullanılamıyor',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fiziksel aktivite iznini verdiğinden emin ol. '
                  'Adım sayımı yalnızca Android ve iOS cihazlarda çalışır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(pedometerProvider.notifier).retry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar dene'),
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: AppColors.surface,
                        color: AppColors.primary,
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            pedometer.isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text('$steps',
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900)),
                            const Text('adım',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Metric(
                          icon: Icons.flag_outlined,
                          label: 'Hedef',
                          value: '$dailyStepGoal adım',
                          color: AppColors.textPrimary),
                      const SizedBox(height: 10),
                      _Metric(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Aktif kalori',
                          value: '$active kcal',
                          color: AppColors.carbs),
                      const SizedBox(height: 10),
                      _Metric(
                          icon: Icons.route_outlined,
                          label: 'Mesafe',
                          value: '${km.toStringAsFixed(2)} km',
                          color: AppColors.secondary),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              Text(value,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickWorkoutCard extends StatelessWidget {
  final VoidCallback onStart;
  const _QuickWorkoutCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E2638), Color(0xFF14352C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'EKİPMANSIZ',
              style: TextStyle(
                color: AppColors.background,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Hızlı Tüm Vücut',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '10 dakika • 10 hareket • 40 sn çalış / 20 sn dinlen',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onStart,
              child: const Text('ANTRENMANA BAŞLA'),
            ),
          ),
        ],
      ),
    );
  }
}
