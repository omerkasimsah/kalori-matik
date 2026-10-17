import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/exercise_library.dart';
import '../data/plan_generator.dart';
import '../providers/weekly_plan_provider.dart';

/// Hedef, yer, gün sayısı, süre ve seviyeye göre haftalık program üretir.
class PlanWizardScreen extends ConsumerStatefulWidget {
  const PlanWizardScreen({super.key});

  @override
  ConsumerState<PlanWizardScreen> createState() => _PlanWizardScreenState();
}

class _PlanWizardScreenState extends ConsumerState<PlanWizardScreen> {
  PlanGoal _goal = PlanGoal.fatLoss;
  PlanPlace _place = PlanPlace.home;
  int _days = 3;
  int _minutes = 30;
  Level _level = Level.beginner;
  bool _busy = false;

  Future<void> _create() async {
    setState(() => _busy = true);
    await ref.read(weeklyPlanProvider.notifier).generate(PlanRequest(
          goal: _goal,
          place: _place,
          daysPerWeek: _days,
          minutes: _minutes,
          level: _level,
        ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sana Özel Program')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(
            'Birkaç soruya cevap ver, sana uygun haftalık antrenman programını oluşturalım.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const _Label('Hedefin'),
          _Options<PlanGoal>(
            values: PlanGoal.values,
            selected: _goal,
            label: (g) => g.label,
            onChanged: (v) => setState(() => _goal = v),
          ),
          const _Label('Nerede antrenman yapacaksın?'),
          _Options<PlanPlace>(
            values: PlanPlace.values,
            selected: _place,
            label: (p) => p.label,
            onChanged: (v) => setState(() => _place = v),
          ),
          const _Label('Haftada kaç gün?'),
          _Options<int>(
            values: const [2, 3, 4, 5, 6],
            selected: _days,
            label: (d) => '$d gün',
            onChanged: (v) => setState(() => _days = v),
          ),
          const _Label('Antrenman süresi'),
          _Options<int>(
            values: const [20, 30, 45, 60],
            selected: _minutes,
            label: (m) => '$m dk',
            onChanged: (v) => setState(() => _minutes = v),
          ),
          const _Label('Seviyen'),
          _Options<Level>(
            values: Level.values,
            selected: _level,
            label: (l) => l.label,
            onChanged: (v) => setState(() => _level = v),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _busy ? null : _create,
            child: const Text('PROGRAMI OLUŞTUR'),
          ),
          const SizedBox(height: 12),
          Text(
            'Program genel bir öneridir. Sağlık sorunun varsa başlamadan önce '
            'doktoruna danış; ağrı hissedersen antrenmanı bırak.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textHint, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      );
}

class _Options<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _Options({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            showCheckmark: false,
            onSelected: (_) => onChanged(v),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.cardSurface,
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            labelStyle: TextStyle(
              color: v == selected ? AppColors.onPrimary : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
