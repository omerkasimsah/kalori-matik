import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';

const _weekDays = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

/// Son günlerin kalori çubukları + hedef çizgisi (koç ve danışan için ortak).
class CalorieWeekChart extends StatelessWidget {
  final List<DailyTotal> totals;
  final int target;

  const CalorieWeekChart({super.key, required this.totals, required this.target});

  @override
  Widget build(BuildContext context) {
    final maxVal = totals
        .map((t) => t.calories.toDouble())
        .fold<double>(target.toDouble(), (a, b) => a > b ? a : b);

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= totals.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_weekDays[totals[i].date.weekday - 1],
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (g, _, __, ___) => BarTooltipItem(
                '${totals[g.x].calories} kcal',
                const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < totals.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: totals[i].calories == 0
                      ? maxVal * 0.02
                      : totals[i].calories.toDouble(),
                  width: 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                  color: totals[i].calories == 0
                      ? AppColors.divider
                      : totals[i].calories > target * 1.1
                          ? AppColors.danger
                          : totals[i].calories >= target * 0.9
                              ? AppColors.primary
                              : AppColors.secondary,
                ),
              ]),
          ],
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(
              y: target.toDouble(),
              color: AppColors.primary.withAlpha(150),
              strokeWidth: 1.2,
              dashArray: [5, 4],
            ),
          ]),
        ),
      ),
    );
  }
}

/// Kilo değişimi çizgi grafiği.
class WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;

  const WeightChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Container(
        height: 110,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text('Grafik için en az 2 kilo kaydı gerekli',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    final first = entries.first.date;
    final xs = [
      for (final e in entries) e.date.difference(first).inHours / 24.0
    ];
    final ws = entries.map((e) => e.weight).toList();
    final minW = (ws.reduce((a, b) => a < b ? a : b).floorToDouble() - 1);
    final maxW = (ws.reduce((a, b) => a > b ? a : b).ceilToDouble() + 1);
    final interval = ((maxW - minW) / 3).ceilToDouble();
    final change = ws.last - ws.first;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 10),
            child: Row(
              children: [
                Text('${ws.last.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  '${change <= 0 ? '' : '+'}${change.toStringAsFixed(1)} kg',
                  style: TextStyle(
                      color: change <= 0 ? AppColors.primary : AppColors.warning,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                minY: minW,
                maxY: maxW,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.divider, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: interval,
                      getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface,
                    getTooltipItems: (spots) => [
                      for (final s in spots)
                        LineTooltipItem('${s.y.toStringAsFixed(1)} kg',
                            const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < ws.length; i++) FlSpot(xs[i], ws[i])
                    ],
                    isCurved: true,
                    barWidth: 3,
                    color: AppColors.secondary,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true, color: AppColors.secondary.withAlpha(30)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
