import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/meal_log.dart';

class MealListItem extends StatelessWidget {
  final MealLog meal;

  const MealListItem({super.key, required this.meal});

  // Metin Madenciliği (Text Mining) Heuristic Modeli
  // Sistem API'den veya kullanıcıdan gelen yemek adını analiz edip 
  // ilgili kategorideki görsel avatara (Emoji) eşleştirerek ikon atar.
  String get _emoji {
    final name = meal.name.toLowerCase();
    if (name.contains('tavuk') || name.contains('et') || name.contains('kıyma')) return '🍗';
    if (name.contains('salata') || name.contains('sebze')) return '🥗';
    if (name.contains('meyve') || name.contains('elma') || name.contains('muz')) return '🍎';
    if (name.contains('makarna') || name.contains('pilav') || name.contains('pirinç')) return '🍝';
    if (name.contains('ekmek') || name.contains('tost') || name.contains('sandviç')) return '🍞';
    if (name.contains('yumurta')) return '🍳';
    if (name.contains('çorba')) return '🍲';
    if (name.contains('pizza')) return '🍕';
    if (name.contains('hamburger') || name.contains('burger')) return '🍔';
    if (name.contains('kahve') || name.contains('çay')) return '☕';
    if (name.contains('kahvaltı')) return '🍳';
    if (name.contains('balık')) return '🐟';
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    // Yapay zeka veya veri tabanı tarafından besin makro değerleri atanmışsa etiketleri görünür kılar
    final hasMacros = meal.protein != null || meal.carbs != null || meal.fat != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji avatar
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
            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meal.insight != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      meal.insight!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (hasMacros) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (meal.protein != null)
                          _MacroBadge(
                              label: 'P',
                              value: '${meal.protein!.toStringAsFixed(0)}g',
                              color: const Color(0xFF3498DB)),
                        if (meal.carbs != null) ...[
                          const SizedBox(width: 6),
                          _MacroBadge(
                              label: 'K',
                              value: '${meal.carbs!.toStringAsFixed(0)}g',
                              color: const Color(0xFFF39C12)),
                        ],
                        if (meal.fat != null) ...[
                          const SizedBox(width: 6),
                          _MacroBadge(
                              label: 'Y',
                              value: '${meal.fat!.toStringAsFixed(0)}g',
                              color: const Color(0xFFE74C3C)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Kalori + saat
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${meal.calories}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'kcal',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  meal.time,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
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
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color),
      ),
    );
  }
}
