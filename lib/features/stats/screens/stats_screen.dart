import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/calorie_provider.dart';

/// Seçili aralık (gün).
final statsRangeProvider = StateProvider<int>((ref) => 7);

/// Seçili aralığın günlük toplamları. Bugünkü öğünler değiştikçe yenilenir.
final dailyTotalsProvider = FutureProvider<List<DailyTotal>>((ref) async {
  ref.watch(currentUserIdProvider);
  ref.watch(caloriesConsumedProvider);
  final days = ref.watch(statsRangeProvider);
  return SupabaseService.getDailyTotals(days: days);
});

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const _weekDays = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(dailyBudgetProvider);
    final range = ref.watch(statsRangeProvider);
    final totalsAsync = ref.watch(dailyTotalsProvider);
    final macros = ref.watch(macrosConsumedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(dailyTotalsProvider.future),
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İstatistikler',
                          style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sağlıklı ilerlemeni takip et',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/history'),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Geçmiş'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 gün')),
                  ButtonSegment(value: 30, label: Text('30 gün')),
                ],
                selected: {range},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(statsRangeProvider.notifier).state = s.first,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) =>
                      states.contains(MaterialState.selected)
                          ? AppColors.primary
                          : AppColors.cardSurface),
                  foregroundColor: MaterialStateProperty.resolveWith((states) =>
                      states.contains(MaterialState.selected)
                          ? AppColors.background
                          : AppColors.textPrimary),
                  side: const MaterialStatePropertyAll(BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              totalsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _InfoCard(
                  child: Column(
                    children: [
                      const Text('Veriler yüklenemedi',
                          style: TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => ref.invalidate(dailyTotalsProvider),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
                data: (totals) => _StatsBody(
                  totals: totals,
                  budget: budget,
                  weekDays: _weekDays,
                ),
              ),
              const SizedBox(height: 28),
              const _SectionTitle(title: 'Bugünkü Makrolar'),
              const SizedBox(height: 12),
              if (macros.protein + macros.carbs + macros.fat == 0)
                const _InfoCard(
                  child: Text('Bugün henüz makro bilgisi olan öğün yok',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                _MacroPieCard(
                  protein: macros.protein,
                  carbs: macros.carbs,
                  fat: macros.fat,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final List<DailyTotal> totals;
  final int budget;
  final List<String> weekDays;

  const _StatsBody({
    required this.totals,
    required this.budget,
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    final logged = totals.where((t) => t.mealCount > 0).toList();
    final avg = logged.isEmpty
        ? 0
        : (logged.fold<int>(0, (s, t) => s + t.calories) / logged.length)
            .round();
    // Hedefin ±%10'u içinde kalınan günler
    final onTarget = logged
        .where((t) => t.calories >= budget * 0.9 && t.calories <= budget * 1.1)
        .length;

    // Seri: bugünden geriye kesintisiz kayıt girilen gün sayısı
    // (bugün henüz kayıt yoksa dünden başlar).
    var streak = 0;
    for (var i = totals.length - 1; i >= 0; i--) {
      if (totals[i].mealCount > 0) {
        streak++;
      } else if (i != totals.length - 1) {
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Günlük Ortalama',
                value: '$avg',
                unit: 'kcal',
                icon: Icons.functions_rounded,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Hedefte Kalınan',
                value: '$onTarget/${logged.length}',
                unit: 'gün',
                icon: Icons.flag_outlined,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Kayıt Serisi',
                value: '$streak',
                unit: 'gün 🔥',
                icon: Icons.local_fire_department_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Günlük Hedef',
                value: '$budget',
                unit: 'kcal',
                icon: Icons.track_changes_rounded,
                color: AppColors.carbs,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionTitle(
            title: totals.length <= 7 ? 'Haftalık Kalori' : 'Aylık Kalori'),
        const SizedBox(height: 12),
        _CalorieBarChart(totals: totals, budget: budget, weekDays: weekDays),
      ],
    );
  }
}

// ── Kalori Bar Grafiği ────────────────────────────────────────────────────────

class _CalorieBarChart extends StatelessWidget {
  final List<DailyTotal> totals;
  final int budget;
  final List<String> weekDays;

  const _CalorieBarChart({
    required this.totals,
    required this.budget,
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = totals
        .map((e) => e.calories.toDouble())
        .fold(budget.toDouble(), (a, b) => a > b ? a : b);
    final isWeek = totals.length <= 7;

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: budget > 0 ? budget / 2 : 500,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (group, _, rod, __) {
                final t = totals[group.x];
                return BarTooltipItem(
                  '${t.date.day}.${t.date.month}\n${t.calories} kcal',
                  const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= totals.length) {
                    return const SizedBox.shrink();
                  }
                  final d = totals[idx].date;
                  // 30 günlük görünümde her 5 günde bir etiket
                  if (!isWeek && (totals.length - 1 - idx) % 5 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isWeek ? weekDays[d.weekday - 1] : '${d.day}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: totals.asMap().entries.map((e) {
            final cal = e.value.calories.toDouble();
            final Color barColor;
            if (cal == 0) {
              barColor = AppColors.divider;
            } else if (cal > budget * 1.1) {
              barColor = AppColors.danger;
            } else if (cal > budget * 0.9) {
              barColor = AppColors.primary;
            } else {
              barColor = AppColors.secondary;
            }
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: cal == 0 ? maxVal * 0.01 : cal,
                  color: barColor,
                  width: isWeek ? 26 : 6,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: budget.toDouble(),
                color: AppColors.primary.withAlpha(180),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  labelResolver: (_) => 'Hedef',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Makro Pasta Grafik ────────────────────────────────────────────────────────

class _MacroPieCard extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;

  const _MacroPieCard(
      {required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    // Kalori katkısına göre yüzdeler (4/4/9)
    final pk = protein * 4, ck = carbs * 4, fk = fat * 9;
    final totalKcal = pk + ck + fk;

    PieChartSectionData section(double v, Color c) => PieChartSectionData(
          value: v,
          color: c,
          title: totalKcal > 0 ? '${(v / totalKcal * 100).round()}%' : '',
          titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.background),
          radius: 52,
        );

    return _InfoCard(
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: [
                  section(pk, AppColors.protein),
                  section(ck, AppColors.carbs),
                  section(fk, AppColors.fat),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MacroLegendRow(
                    color: AppColors.protein,
                    label: 'Protein',
                    value: '${protein.toStringAsFixed(1)}g'),
                const SizedBox(height: 12),
                _MacroLegendRow(
                    color: AppColors.carbs,
                    label: 'Karbonhidrat',
                    value: '${carbs.toStringAsFixed(1)}g'),
                const SizedBox(height: 12),
                _MacroLegendRow(
                    color: AppColors.fat,
                    label: 'Yağ',
                    value: '${fat.toStringAsFixed(1)}g'),
                const Divider(height: 20),
                const Text('Yüzdeler kalori katkısına göre',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _MacroLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ── Yardımcı Widget'lar ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                      text: value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary),
    );
  }
}
