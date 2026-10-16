import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/exercise_library.dart';
import '../widgets/exercise_media.dart';

Color _muscleColor(Muscle m) => AppColors.primary;

/// Kas grubuna göre filtrelenebilen, aranabilir egzersiz kütüphanesi.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  Muscle? _muscle;
  bool _noEquipmentOnly = false;

  List<Exercise> get _filtered {
    final q = _query.trim().toLowerCase();
    return [
      for (final e in exerciseLibrary)
        if ((_muscle == null || e.muscle == _muscle) &&
            (!_noEquipmentOnly || e.equipment == Equipment.none) &&
            (q.isEmpty || e.name.toLowerCase().contains(q)))
          e
    ];
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Egzersiz Kütüphanesi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Egzersiz ara…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _Chip(
                    label: 'Tümü',
                    selected: _muscle == null,
                    onTap: () => setState(() => _muscle = null)),
                for (final m in Muscle.values)
                  _Chip(
                      label: m.label,
                      selected: _muscle == m,
                      onTap: () => setState(() => _muscle = m)),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            dense: true,
            title: Text('Sadece ekipmansız',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            value: _noEquipmentOnly,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _noEquipmentOnly = v),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('Sonuç bulunamadı',
                        style: TextStyle(color: AppColors.textSecondary)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => ExerciseTile(exercise: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

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

/// Liste satırı: ikon, ad, kas/ekipman ve önerilen set × tekrar.
class ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const ExerciseTile({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final color = _muscleColor(e.muscle);
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(exercise: e))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ExerciseThumb(exerciseId: e.id, fallback: e.muscle.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('${e.muscle.label} • ${e.equipment.label} • ${e.level.label}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text(e.prescription,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final color = _muscleColor(e.muscle);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          if (hasExerciseMedia(e.id))
            ExerciseAnimation(exerciseId: e.id, height: 240)
          else
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Icon(e.muscle.icon,
                    size: 64, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 20),
          Text(e.name,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag(e.muscle.label, color),
              _Tag(e.equipment.label, AppColors.textSecondary),
              _Tag(e.level.label, AppColors.carbs),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat('Set', '${e.sets}'),
                _Stat(e.isTimed ? 'Süre' : 'Tekrar',
                    e.isTimed ? '${e.durationSec}sn' : '${e.reps}'),
                _Stat('Dinlenme', '${e.restSec}sn'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('NASIL YAPILIR',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1)),
          const SizedBox(height: 12),
          for (var i = 0; i < e.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: color.withAlpha(35), shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(e.steps[i],
                        style: TextStyle(
                            color: AppColors.textPrimary, height: 1.4)),
                  ),
                ],
              ),
            ),
          if (e.tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(50)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.tips_and_updates_outlined,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('İpuçları',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 8),
                  for (final t in e.tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $t',
                          style: TextStyle(
                              color: AppColors.textSecondary, height: 1.4)),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Yeni bir harekete başlarken hafif ağırlıkla formu öğren. '
            'Ağrı hissedersen dur ve bir uzmana danış.',
            style: TextStyle(color: AppColors.textHint, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      );
}
