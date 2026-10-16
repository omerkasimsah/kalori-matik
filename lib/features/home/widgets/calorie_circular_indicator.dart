import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/calorie_provider.dart';

class CalorieCircularIndicator extends ConsumerWidget {
  const CalorieCircularIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(remainingBudgetProvider); // Kalan bakiye
    final total = ref.watch(dailyBudgetProvider);           // Günlük hedef
    final consumed = ref.watch(caloriesConsumedProvider);   // Alınan enerji
    final active = ref.watch(activeCaloriesProvider);       // Adımlardan kazanılan

    // Doluluk oranı: yenen / (hedef + aktivite)
    final available = total + active;
    final progress =
        available > 0 ? (consumed / available).clamp(0.0, 1.0) : 0.0;
    final over = remaining < 0;

    final Color progressColor;
    final String statusLabel;
    if (over) {
      progressColor = AppColors.danger;
      statusLabel =
          'Limiti ${-remaining} kcal aştın. 30 dakikalık tempolu bir yürüyüş dengeyi toparlar 🚶';
    } else if (progress > 0.85) {
      progressColor = AppColors.warning;
      statusLabel = 'Kırmızı çizgiye yaklaştın, akşam hafif bir öğün seç.';
    } else if (consumed == 0) {
      progressColor = AppColors.primary;
      statusLabel = 'Güne hazırsın! İlk öğününü ekleyerek başla.';
    } else {
      progressColor = AppColors.primary;
      statusLabel = 'Bakiye tıkırında, harika gidiyorsun!';
    }

    return Column(
      children: [
        // Dairesel halka
        SizedBox(
          width: 230,
          height: 230,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: over ? 1.0 : 1 - progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 22,
                    color: AppColors.cardSurface, // Koyu halka zemini
                  ),
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 22,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    strokeCap: StrokeCap.round,
                  ),
                  // Merkez içerik
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${remaining.abs()}',
                          style: TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w900,
                            color: progressColor,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          over ? 'KCAL fazla' : 'KCAL kalan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Durum etiketi (Akıllı Microcopy)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: progressColor.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: progressColor.withAlpha(50)),
          ),
          child: Text(
            statusLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: progressColor,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Alt özet satırı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryTile(
                label: 'Hedef',
                value: '$total',
                unit: 'kcal',
                color: AppColors.textPrimary,
              ),
              Container(width: 1, height: 36, color: AppColors.divider),
              _SummaryTile(
                label: 'Yenen',
                value: '$consumed',
                unit: 'kcal',
                color: AppColors.carbs,
              ),
              Container(width: 1, height: 36, color: AppColors.divider),
              _SummaryTile(
                label: 'Aktivite',
                value: '+$active',
                unit: 'kcal',
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
