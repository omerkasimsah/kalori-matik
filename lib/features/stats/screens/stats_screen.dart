import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/providers/calorie_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  // Haftalık Kalori Geçmişi Veri Modeli
  List<Map<String, dynamic>> _weeklyData = [];
  // Supabase'den ilk yükleme için ağ iletişim bayrağı
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Grafiklere çizilecek analiz datasını çekmeye başlar
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.getWeeklyCalories();
      if (mounted) setState(() => _weeklyData = data);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Kapsamlı (Global) Riverpod durumlarının dinlenmesi
    final budget = ref.watch(dailyBudgetProvider);
    final consumed = ref.watch(caloriesConsumedProvider);
    final mealsState = ref.watch(mealLogsProvider);

    // Günlük makro hedefleri için veri toplama (Aggregate) algoritması
    double totalProtein = 0, totalCarbs = 0, totalFat = 0;
    for (final m in mealsState.meals) {
      totalProtein += m.protein ?? 0;
      totalCarbs += m.carbs ?? 0;
      totalFat += m.fat ?? 0;
    }
    final totalMacros = totalProtein + totalCarbs + totalFat;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // ── Başlık ────────────────────────────────────────────
                    const Text(
                      'İstatistikler',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sağlıklı ilerlemenizi takip edin',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // ── Özet kartlar ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Günlük Limit',
                            value: '$budget',
                            unit: 'kcal',
                            icon: Icons.flag_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Bugün Harcanan',
                            value: '$consumed',
                            unit: 'kcal',
                            icon: Icons.local_fire_department_outlined,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Bugün Kalan',
                            value: '${(budget - consumed).clamp(0, budget)}',
                            unit: 'kcal',
                            icon: Icons.savings_outlined,
                            color: budget - consumed > 0
                                ? AppColors.primary
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'Öğün Sayısı',
                            value: '${mealsState.meals.length}',
                            unit: 'öğün',
                            icon: Icons.restaurant_outlined,
                            color: const Color(0xFF9B59B6),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Haftalık Kalori Grafiği ───────────────────────────
                    _SectionTitle(title: 'Haftalık Kalori'),
                    const SizedBox(height: 12),
                    _WeeklyBarChart(weeklyData: _weeklyData, budget: budget),

                    const SizedBox(height: 28),

                    // ── Bugünkü Makro Dağılımı ───────────────────────────
                    _SectionTitle(title: 'Bugünkü Makrolar'),
                    const SizedBox(height: 12),
                    if (totalMacros == 0)
                      _EmptyMacroCard()
                    else
                      _MacroPieCard(
                        protein: totalProtein,
                        carbs: totalCarbs,
                        fat: totalFat,
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Haftalık Bar Grafiği ──────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  final int budget;

  const _WeeklyBarChart({required this.weeklyData, required this.budget});

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text('Henüz veri yok',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    // Grafiğin Y-Ekseni ölçeklemesi için en yüksek değeri bulma algoritması (Peak Detection)
    final maxVal = weeklyData
            .map((e) => (e['calories'] as int).toDouble())
            .fold(0.0, (a, b) => a > b ? a : b)
        .clamp(budget.toDouble(), double.infinity);

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: budget / 2,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade100,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= weeklyData.length)
                    return const Text('');
                  return Text(
                    weeklyData[idx]['date'] as String,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary),
                  );
                },
              ),
            ),
          ),
          barGroups: weeklyData.asMap().entries.map((e) {
            final cal = (e.value['calories'] as int).toDouble();
            Color barColor;
            if (cal == 0) {
              barColor = Colors.grey.shade200;
            } else if (cal > budget) {
              barColor = AppColors.danger;
            } else if (cal > budget * 0.85) {
              barColor = AppColors.warning;
            } else {
              barColor = AppColors.primary;
            }
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: cal == 0 ? 0.5 : cal,
                  color: barColor,
                  width: 28,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal * 1.15,
                    color: Colors.grey.shade50,
                  ),
                ),
              ],
            );
          }).toList(),
          // Hedef çizgisi
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
    final total = protein + carbs + fat;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: [
                  PieChartSectionData(
                    value: protein,
                    color: const Color(0xFF3498DB),
                    title: '${(protein / total * 100).round()}%',
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    radius: 52,
                  ),
                  PieChartSectionData(
                    value: carbs,
                    color: const Color(0xFFF39C12),
                    title: '${(carbs / total * 100).round()}%',
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    radius: 52,
                  ),
                  PieChartSectionData(
                    value: fat,
                    color: const Color(0xFFE74C3C),
                    title: '${(fat / total * 100).round()}%',
                    titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    radius: 52,
                  ),
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
                    color: const Color(0xFF3498DB),
                    label: 'Protein',
                    value: '${protein.toStringAsFixed(1)}g'),
                const SizedBox(height: 12),
                _MacroLegendRow(
                    color: const Color(0xFFF39C12),
                    label: 'Karbonhidrat',
                    value: '${carbs.toStringAsFixed(1)}g'),
                const SizedBox(height: 12),
                _MacroLegendRow(
                    color: const Color(0xFFE74C3C),
                    label: 'Yağ',
                    value: '${fat.toStringAsFixed(1)}g'),
                const Divider(height: 20),
                _MacroLegendRow(
                    color: AppColors.textSecondary,
                    label: 'Toplam',
                    value: '${total.toStringAsFixed(1)}g',
                    isBold: true),
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
  final bool isBold;

  const _MacroLegendRow({
    required this.color,
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.normal)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}

class _EmptyMacroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const Center(
        child: Text('Bugün henüz öğün eklenmedi',
            style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}

// ── Yardımcı Widget'lar ───────────────────────────────────────────────────────

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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
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
          RichText(
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
