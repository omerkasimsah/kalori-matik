import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/workout_programs.dart';
import 'exercise_screens.dart';

/// Program özeti: süre, seviye, ekipman ve egzersiz listesi. [onStart] ile başlar.
class ProgramDetailScreen extends StatelessWidget {
  final WorkoutProgram program;
  final VoidCallback onStart;

  const ProgramDetailScreen(
      {super.key, required this.program, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final p = program;
    final equipment = p.equipment.map((e) => e.label).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: p.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(p.icon, color: Colors.white.withAlpha(230), size: 34),
                    const SizedBox(height: 8),
                    Text(p.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                    Text(p.subtitle,
                        style: TextStyle(
                            color: Colors.white.withAlpha(220), fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(child: _Info(Icons.timer_outlined, '${p.estimatedMinutes} dk', 'Süre')),
                    const SizedBox(width: 10),
                    Expanded(child: _Info(Icons.list_alt, '${p.items.length}', 'Egzersiz')),
                    const SizedBox(width: 10),
                    Expanded(child: _Info(Icons.speed, p.level.label, 'Seviye')),
                  ],
                ),
                const SizedBox(height: 12),
                _Info(
                  Icons.fitness_center,
                  equipment.isEmpty ? 'Ekipman gerekmez' : equipment.join(', '),
                  'Ekipman',
                  wide: true,
                ),
                const SizedBox(height: 24),
                const Text('EGZERSİZLER',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1)),
                const SizedBox(height: 12),
                for (final item in p.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProgramRow(item: item),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Isınmadan başlama; ilk setlerde hafif ağırlık kullan. '
                  'Ağrı hissedersen dur ve bir uzmana danış.',
                  style: TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onStart();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ANTRENMANA BAŞLA'),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool wide;
  const _Info(this.icon, this.value, this.label, {this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramRow extends StatelessWidget {
  final ProgramItem item;
  const _ProgramRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final e = item.exercise;
    final dur = item.effectiveDuration;
    final rx = dur != null
        ? '${item.effectiveSets} × ${dur}sn'
        : '${item.effectiveSets} × ${item.effectiveReps}';
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(exercise: e))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(e.muscle.icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    Text(e.muscle.label,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(rx,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
