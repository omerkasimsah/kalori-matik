import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/models/meal_log.dart';
import '../../home/widgets/meal_list_item.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Supabase'den çekilen tüm geçmiş öğünlerin (MealLog) listesini tutar.
  List<MealLog> _allMeals = [];
  // Ağ isteği (Network Request) atılırken ekranda loading animasyonu göstermek için kullanılır.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Ekran ilk açıldığında geçmiş verileri çekmeye başla
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final meals = await SupabaseService.getAllMeals(days: 30);
      if (mounted) setState(() => _allMeals = meals);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  /// Geçmiş Öğünleri veritabanından getirir, tarih etiketleriyle gruplar.
  /// Veritabanından gelen veriler sıralı (Descending - en yeniler en üstte) olarak kabul edilir.
  Map<String, List<MealLog>> _groupByDate() {
    final Map<String, List<MealLog>> grouped = {};
    for (final meal in _allMeals) {
      // Şimdilik gelişmiş 'date' field'ı modelde olmadığı için geçici gün gruplaması yapılır.
      // Modüler mimari (Faz 3) kapsamında modelin datetime alanlarına entegre edilecek.
      final label = _dateLabel(meal);
      grouped.putIfAbsent(label, () => []).add(meal);
    }
    return grouped;
  }

  String _dateLabel(MealLog meal) {
    // Mimari Not: Geçici Placeholder (Zaman Damgası mantığı _groupMealsByCreationOrder içinde asıl çalışıyor)
    return 'Geçmiş Öğünler'; 
  }

  @override
  Widget build(BuildContext context) {
    // Tarihe göre daha iyi gruplama için _allMeals'i indeks bazlı işleyelim
    final grouped = _groupMealsByCreationOrder(_allMeals);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : RefreshIndicator(
                onRefresh: _loadHistory,
                color: AppColors.primary,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Geçmiş',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Son ${grouped.length} gün',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_allMeals.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history,
                                  size: 64,
                                  color: AppColors.textHint),
                              SizedBox(height: 12),
                              Text('Henüz geçmiş öğün yok',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 15)),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final entry =
                                grouped.entries.elementAt(index);
                            final dateLabel = entry.key;
                            final meals = entry.value;
                            final totalCal = meals.fold(
                                0, (sum, m) => sum + m.calories);

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  20, 20, 20, 0),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Gün başlığı
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateLabel,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withAlpha(20),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$totalCal kcal',
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Öğün listesi
                                  ...meals.map((m) => MealListItem(meal: m)),
                                ],
                              ),
                            );
                          },
                          childCount: grouped.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
      ),
    );
  }

  /// Öğün listesini, eklenme sırasına ve saat damgasına bakarak 'Bugün', 'Dün'
  /// veya güncel DD/MM formatına göre görsel bir haritaya (Map) dönüştürür.
  Map<String, List<MealLog>> _groupMealsByCreationOrder(
      List<MealLog> meals) {
    // Mimari Algoritma: 
    // Supabase'den dönen liste Order By descending (en yeni en üstte) ile geziyor.
    // Eğer sıradaki öğünün saati (öğle) kendinden önceki listede olan öğünden (akşam) daha büyükse
    // Mantıksal olarak bir önceki güne geçiş yapmışız demektir (Aynı günde geriye doğru gitme).
    // Bu sayede backend tarafında ekstra Date sütunu olmaksızın Front-end tarafında Heuristic gruplama elde ediliyor.
    final now = DateTime.now();
    final today =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yest =
        '${yesterday.day.toString().padLeft(2, '0')}/${yesterday.month.toString().padLeft(2, '0')}';

    final Map<String, List<MealLog>> result = {};
    int dayOffset = 0;
    String? prevTime;

    for (final meal in meals) {
      if (prevTime != null && meal.time.compareTo(prevTime!) > 0) {
        dayOffset++;
      }
      prevTime = meal.time;

      final d = now.subtract(Duration(days: dayOffset));
      final key =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

      String label;
      if (key == today) {
        label = 'Bugün';
      } else if (key == yest) {
        label = 'Dün';
      } else {
        label = key;
      }
      result.putIfAbsent(label, () => []).add(meal);
    }
    return result;
  }
}
