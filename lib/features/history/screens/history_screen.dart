import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/models/meal_log.dart';
import '../../home/providers/calorie_provider.dart';
import '../../home/widgets/meal_list_item.dart';

/// Son 30 günün öğünleri.
final historyProvider = FutureProvider.autoDispose<List<MealLog>>((ref) {
  ref.watch(currentUserIdProvider);
  return SupabaseService.getAllMeals(days: 30);
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  static const _weekDays = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
  ];

  /// Öğünleri yerel tarihe göre (yeniden eskiye) gruplar.
  static Map<DateTime, List<MealLog>> groupByDay(List<MealLog> meals) {
    final grouped = <DateTime, List<MealLog>>{};
    for (final m in meals) {
      grouped.putIfAbsent(m.day, () => []).add(m);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: grouped[k]!};
  }

  static String dayLabel(DateTime day, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    return '${day.day} ${_months[day.month - 1]}, ${_weekDays[day.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    final budget = ref.watch(dailyBudgetProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Geçmiş (30 gün)')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(historyProvider.future),
        color: AppColors.primary,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(
                child: Text('Geçmiş yüklenemedi',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(historyProvider),
                  child: const Text('Tekrar dene'),
                ),
              ),
            ],
          ),
          data: (meals) {
            if (meals.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.history, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Center(
                    child: Text('Henüz geçmiş öğün yok',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 15)),
                  ),
                ],
              );
            }

            final grouped = groupByDay(meals);
            final entries = grouped.entries.toList();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final totalCal =
                    entry.value.fold(0, (sum, m) => sum + m.calories);
                final over = totalCal > budget * 1.1;

                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dayLabel(entry.key),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: (over ? AppColors.danger : AppColors.primary)
                                  .withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$totalCal / $budget kcal',
                              style: TextStyle(
                                  color: over
                                      ? AppColors.danger
                                      : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...entry.value.map((m) => MealListItem(meal: m)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
