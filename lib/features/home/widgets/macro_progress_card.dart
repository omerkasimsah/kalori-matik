import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/calorie_provider.dart';

/// Günlük protein / karbonhidrat / yağ hedeflerine göre ilerleme.
class MacroProgressCard extends ConsumerWidget {
  const MacroProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(macroTargetsProvider);
    final consumed = ref.watch(macrosConsumedProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MacroBar(
              label: 'Protein',
              value: consumed.protein,
              target: targets.protein,
              color: AppColors.protein,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _MacroBar(
              label: 'Karb',
              value: consumed.carbs,
              target: targets.carbs,
              color: AppColors.carbs,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _MacroBar(
              label: 'Yağ',
              value: consumed.fat,
              target: targets.fat,
              color: AppColors.fat,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value;
  final int target;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final over = value > target * 1.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: color.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(over ? AppColors.warning : color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value.toStringAsFixed(0),
                style: TextStyle(
                    color: over ? AppColors.warning : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
              TextSpan(
                text: ' / ${target}g',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
