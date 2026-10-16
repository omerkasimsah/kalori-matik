import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/meal_log.dart';

class MealListItem extends StatelessWidget {
  final MealLog meal;

  /// Dokunulduğunda (ör. düzenleme) çağrılır.
  final VoidCallback? onTap;

  /// Verilirse öğün sola kaydırılarak silinebilir.
  final VoidCallback? onDelete;

  const MealListItem({
    super.key,
    required this.meal,
    this.onTap,
    this.onDelete,
  });

  // Yemek adını analiz edip ilgili kategorideki emojiyi eşleştirir.
  String get _emoji {
    final name = meal.name.toLowerCase();
    bool has(List<String> words) => words.any(name.contains);
    if (has(['yumurta', 'omlet', 'menemen', 'kahvaltı'])) return '🍳';
    if (has(['tavuk', 'piliç'])) return '🍗';
    if (has(['köfte', 'kebap', 'kıyma', 'biftek', 'döner', 'et '])) return '🥩';
    if (has(['balık', 'somon', 'ton '])) return '🐟';
    if (has(['salata', 'sebze', 'brokoli'])) return '🥗';
    if (has(['çorba'])) return '🍲';
    if (has(['pizza'])) return '🍕';
    if (has(['burger'])) return '🍔';
    if (has(['makarna', 'spagetti', 'erişte'])) return '🍝';
    if (has(['pilav', 'pirinç', 'bulgur'])) return '🍚';
    if (has(['ekmek', 'tost', 'sandviç', 'simit', 'poğaça'])) return '🥪';
    if (has(['meyve', 'elma', 'muz', 'portakal', 'çilek'])) return '🍎';
    if (has(['yoğurt', 'süt', 'ayran', 'peynir'])) return '🥛';
    if (has(['tatlı', 'pasta', 'kek', 'çikolata', 'baklava', 'dondurma'])) {
      return '🍰';
    }
    if (has(['kahve', 'çay'])) return '☕';
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    final hasMacros =
        meal.protein != null || meal.carbs != null || meal.fat != null;

    final card = Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(_emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (meal.insight != null && meal.insight!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        meal.insight!,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (meal.hasCoachComment) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.support_agent_rounded,
                                size: 15, color: AppColors.secondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(meal.coachComment!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (hasMacros) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (meal.protein != null)
                            _MacroBadge(
                                label: 'P',
                                value: '${meal.protein!.toStringAsFixed(0)}g',
                                color: AppColors.protein),
                          if (meal.carbs != null)
                            _MacroBadge(
                                label: 'K',
                                value: '${meal.carbs!.toStringAsFixed(0)}g',
                                color: AppColors.carbs),
                          if (meal.fat != null)
                            _MacroBadge(
                                label: 'Y',
                                value: '${meal.fat!.toStringAsFixed(0)}g',
                                color: AppColors.fat),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${meal.calories}',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'kcal',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meal.time,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: card,
    );

    if (onDelete == null) return content;

    return Dismissible(
      key: ValueKey('meal-${meal.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete!(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.danger.withAlpha(40),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sil',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: AppColors.danger),
          ],
        ),
      ),
      child: content,
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style:
            TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
