import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/calorie_provider.dart';
import '../data/sports.dart';
import '../data/workout_programs.dart';
import '../providers/activity_log_provider.dart';
import '../providers/pedometer_provider.dart';
import 'active_workout_screen.dart';
import 'exercise_screens.dart';
import 'program_detail_screen.dart';

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

/// Seçili program kategorisi (null = hepsi).
final programFilterProvider = StateProvider<ProgramCategory?>((ref) => null);

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

  /// Antrenmanı başlatır; bitince süreyi aktivite olarak kaydeder.
  static Future<void> startWorkout(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<WorkoutStep> steps,
    required String sportId,
  }) async {
    final minutes = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => ActiveWorkoutScreen(title: title, steps: steps),
    ));
    if (minutes == null) return;
    final weight = ref.read(userWeightProvider) ?? 70;
    final sport = sportById(sportId);
    await ref.read(activityLogProvider.notifier).add(
        title: title, sport: sport, minutes: minutes, weightKg: weight);
    if (context.mounted) {
      final kcal = sport.caloriesFor(minutes: minutes, weightKg: weight);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$title kaydedildi • $minutes dk • $kcal kcal 🔥')));
    }
  }

  static String _sportFor(ProgramCategory c) => switch (c) {
        ProgramCategory.gym || ProgramCategory.home => 'gym',
        ProgramCategory.cardio => 'hiit',
        ProgramCategory.flexibility => 'yoga',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(myWorkoutPlansProvider).valueOrNull ?? const [];
    final filter = ref.watch(programFilterProvider);
    final programs = [
      for (final p in workoutPrograms)
        if (filter == null || p.category == filter) p
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myWorkoutPlansProvider);
          await ref.read(activityLogProvider.notifier).refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              title: Text('Aktivite',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
              sliver: SliverToBoxAdapter(child: _StepsCard()),
            ),

            // ── Bugünkü aktiviteler ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _TodayActivities()),
            ),

            // ── Koçun planları ───────────────────────────────────────────
            if (plans.isNotEmpty) ...[
              const _SectionHeader('KOÇUNUN PLANLARI'),
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
                            leading: CircleAvatar(
                              backgroundColor: AppColors.surface,
                              child: Icon(Icons.support_agent_rounded,
                                  color: AppColors.secondary),
                            ),
                            title: Text(title,
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              [
                                if (plan['week_day'] != null) plan['week_day'],
                                '$count egzersiz',
                              ].join(' • '),
                              style: TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                            trailing: Icon(Icons.play_circle_fill,
                                color: AppColors.primary, size: 36),
                            onTap: count == 0
                                ? null
                                : () => startWorkout(context, ref,
                                    title: title, steps: steps, sportId: 'gym'),
                          ),
                        ),
                      );
                    },
                    childCount: plans.length,
                  ),
                ),
              ),
            ],

            // ── Hazır programlar ─────────────────────────────────────────
            const _SectionHeader('ANTRENMAN PROGRAMLARI'),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _FilterChip(
                        label: 'Tümü',
                        selected: filter == null,
                        onTap: () => ref
                            .read(programFilterProvider.notifier)
                            .state = null),
                    for (final c in ProgramCategory.values)
                      _FilterChip(
                          label: c.label,
                          selected: filter == c,
                          onTap: () => ref
                              .read(programFilterProvider.notifier)
                              .state = c),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: programs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final p = programs[i];
                    return _ProgramCard(
                      program: p,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProgramDetailScreen(
                            program: p,
                            onStart: () => startWorkout(context, ref,
                                title: p.title,
                                steps: p.toSteps(),
                                sportId: _sportFor(p.category)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Kütüphane ───────────────────────────────────────────────
            const _SectionHeader('KEŞFET'),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Material(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ExerciseLibraryScreen())),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(28),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.menu_book_rounded,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Egzersiz Kütüphanesi',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(
                                    'Her hareketin nasıl yapıldığını adım adım öğren',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
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

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      sliver: SliverToBoxAdapter(
        child: Text(text,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.cardSurface,
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: selected ? AppColors.background : AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final WorkoutProgram program;
  final VoidCallback onTap;
  const _ProgramCard({required this.program, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = program;
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(p.icon, color: AppColors.onPrimary, size: 20),
                  ),
                  const Spacer(),
                  Text(p.level.label,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const Spacer(),
              Text(p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.2)),
              const SizedBox(height: 4),
              Text('${p.estimatedMinutes} dk • ${p.items.length} egzersiz',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bugünkü aktiviteler ──────────────────────────────────────────────────────

class _TodayActivities extends ConsumerWidget {
  Future<void> _addSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _LogActivitySheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(activityLogProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Bugünkü Aktiviteler',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
              TextButton.icon(
                onPressed: () => _addSheet(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Spor ekle'),
              ),
            ],
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Henüz aktivite yok. Koşu, yüzme, futbol… ne yaptıysan ekle; '
                'yaktığın kalori günlük bütçene eklenir.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
            )
          else
            for (final e in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(e.sport.icon, color: AppColors.primary, size: 20),
                ),
                title: Text(e.title,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                subtitle: Text('${e.minutes} dk',
                    style: TextStyle(color: AppColors.textSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('+${e.calories} kcal',
                        style: TextStyle(
                            color: AppColors.carbs,
                            fontWeight: FontWeight.w800)),
                    IconButton(
                      tooltip: 'Sil',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close,
                          size: 18, color: AppColors.textSecondary),
                      onPressed: () =>
                          ref.read(activityLogProvider.notifier).remove(e.id),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _LogActivitySheet extends ConsumerStatefulWidget {
  const _LogActivitySheet();

  @override
  ConsumerState<_LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends ConsumerState<_LogActivitySheet> {
  Sport _sport = sports.first;
  double _minutes = 30;

  @override
  Widget build(BuildContext context) {
    final weight = ref.watch(userWeightProvider) ?? 70;
    final kcal = _sport.caloriesFor(minutes: _minutes.round(), weightKg: weight);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Aktivite ekle',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sports)
                ChoiceChip(
                  avatar: Icon(s.icon,
                      size: 18,
                      color: _sport == s
                          ? AppColors.background
                          : AppColors.textSecondary),
                  label: Text(s.name),
                  selected: _sport == s,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _sport = s),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.cardSurface,
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: _sport == s
                        ? AppColors.background
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Süre',
                  style: TextStyle(color: AppColors.textSecondary)),
              Text('${_minutes.round()} dk',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          Slider(
            value: _minutes,
            min: 5,
            max: 180,
            divisions: 35,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _minutes = v),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.carbs.withAlpha(22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department,
                    color: AppColors.carbs),
                const SizedBox(width: 8),
                Text('≈ $kcal kcal yakılır',
                    style: TextStyle(
                        color: AppColors.carbs, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await ref.read(activityLogProvider.notifier).add(
                  title: _sport.name,
                  sport: _sport,
                  minutes: _minutes.round(),
                  weightKg: weight);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

// ── Adım kartı ───────────────────────────────────────────────────────────────

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
                Icon(Icons.directions_walk,
                    size: 40, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text('Adım sayar kullanılamıyor',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  'Fiziksel aktivite iznini verdiğinden emin ol. '
                  'Adım sayımı yalnızca Android ve iOS cihazlarda çalışır.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900)),
                            Text('adım',
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
                      _Metric(
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
                  style: TextStyle(
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
