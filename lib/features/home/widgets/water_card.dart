import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/water_provider.dart';

/// Hızlı ekleme butonlarıyla günlük su takibi.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key});

  String _liters(int ml) => (ml / 1000).toStringAsFixed(ml % 1000 == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intake = ref.watch(waterIntakeProvider);
    final goal = ref.watch(waterGoalProvider);
    final notifier = ref.read(waterIntakeProvider.notifier);
    final progress = goal > 0 ? (intake / goal).clamp(0.0, 1.0) : 0.0;
    final done = intake >= goal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.water.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.water_drop_rounded,
                    color: AppColors.water, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Su',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                    Text(
                      done
                          ? 'Hedef tamam! 🎉'
                          : '${_liters(intake)} / ${_liters(goal)} L',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Geri al (−250 ml)',
                visualDensity: VisualDensity.compact,
                onPressed: intake > 0 ? () => notifier.add(-250) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.textSecondary,
              ),
              _AddButton(label: '+250', onTap: () => notifier.add(250)),
              const SizedBox(width: 6),
              _AddButton(label: '+500', onTap: () => notifier.add(500)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: AppColors.water.withAlpha(30),
                valueColor: AlwaysStoppedAnimation(AppColors.water),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.water.withAlpha(30),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(label,
              style: TextStyle(
                  color: AppColors.water,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ),
    );
  }
}
