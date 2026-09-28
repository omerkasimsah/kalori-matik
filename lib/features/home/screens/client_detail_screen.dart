import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../home/models/meal_log.dart';

// ────────────────────────────────────────────────────────────────────────────
// Danışan Detay Ekranı — Koç/Diyetisyen perspektifinden tam yönetim
// ────────────────────────────────────────────────────────────────────────────
class ClientDetailScreen extends StatefulWidget {
  final Map<String, dynamic> clientProfile;

  const ClientDetailScreen({super.key, required this.clientProfile});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  bool _isLoading = true;
  List<MealLog> _todayMeals = [];
  List<Map<String, dynamic>> _workoutPlans = [];
  List<Map<String, dynamic>> _nutritionPlan = [];
  List<Map<String, dynamic>> _coachNotes = [];

  late int _currentTdee;
  late int _stepTarget;

  // Egzersiz kategori tanımları
  static const _exerciseCategories = [
    _ExCat('Güç / Ağırlık', Icons.fitness_center, Color(0xFF3D5AF1)),
    _ExCat('Kardio', Icons.directions_run, Color(0xFFFF6B35)),
    _ExCat('HIIT', Icons.bolt, Color(0xFFFF4D6D)),
    _ExCat('Esneklik', Icons.self_improvement, Color(0xFF8B5CF6)),
    _ExCat('Fonksiyonel', Icons.sports_gymnastics, Color(0xFF00C896)),
    _ExCat('Serbest', Icons.edit, Color(0xFF6B7694)),
  ];

  static const _mealTimes = [
    'Kahvaltı', 'Öğle Yemeği', 'Akşam Yemeği',
    'Ara Öğün 1', 'Ara Öğün 2', 'Egzersiz Öncesi', 'Egzersiz Sonrası',
  ];

  static const _noteCategories = [
    _NoteCat('Genel', Icons.notes, AppColors.primary),
    _NoteCat('Beslenme', Icons.restaurant, Color(0xFFFF6B35)),
    _NoteCat('Antrenman', Icons.fitness_center, Color(0xFF3D5AF1)),
    _NoteCat('Motivasyon', Icons.star, Color(0xFFFFB347)),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _currentTdee = (widget.clientProfile['daily_tdee'] as num?)?.toInt() ?? 2000;
    _stepTarget = (widget.clientProfile['step_target'] as num?)?.toInt() ?? 8000;
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final clientId = widget.clientProfile['id'].toString();
      final results = await Future.wait([
        SupabaseService.getClientTodayMeals(clientId),
        SupabaseService.getWorkoutPlans(clientId),
        SupabaseService.getNutritionPlan(clientId),
        SupabaseService.getCoachNotes(clientId),
      ]);
      if (mounted) {
        setState(() {
          _todayMeals = results[0] as List<MealLog>;
          _workoutPlans = results[1] as List<Map<String, dynamic>>;
          _nutritionPlan = results[2] as List<Map<String, dynamic>>;
          _coachNotes = results[3] as List<Map<String, dynamic>>;
        });
      }
    } catch (e) {
      _showError('Veri yüklenemedi: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  // ── Kalori / Adım Hedefi Düzenleme ──────────────────────────────────────
  void _showEditGoalsDialog() {
    final tdeeCtrl = TextEditingController(text: _currentTdee.toString());
    final stepCtrl = TextEditingController(text: _stepTarget.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hedefleri Düzenle',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(
              ctrl: tdeeCtrl,
              label: 'Günlük Kalori Limiti (kcal)',
              icon: Icons.local_fire_department,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            _buildDialogField(
              ctrl: stepCtrl,
              label: 'Günlük Adım Hedefi',
              icon: Icons.directions_walk,
              color: AppColors.secondary,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final tdee = int.tryParse(tdeeCtrl.text);
              final step = int.tryParse(stepCtrl.text);
              Navigator.pop(ctx);
              if (tdee != null && step != null) {
                setState(() {
                  _currentTdee = tdee;
                  _stepTarget = step;
                });
                await SupabaseService.updateClientProfile(
                  widget.clientProfile['id'].toString(),
                  {'daily_tdee': tdee, 'step_target': step},
                );
                _showSuccess('Hedefler güncellendi ✅');
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── Antrenman Planı Eka ───────────────────────────────────────────────────
  void _showCreatePlanSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedDay;

    const days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _BottomSheet(
          title: 'Antrenman Planı Oluştur',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetField(ctrl: titleCtrl, label: 'Plan Adı', hint: 'ör. Göğüs & Sırt Günü'),
              const SizedBox(height: 12),
              _SheetField(ctrl: descCtrl, label: 'Açıklama (opsiyonel)', hint: 'Notlar...', maxLines: 2),
              const SizedBox(height: 12),
              const Text('Gün', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: days.map((d) {
                  final sel = selectedDay == d;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedDay = d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.secondary : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? AppColors.secondary : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(d,
                          style: TextStyle(
                            color: sel ? Colors.white : AppColors.textSecondary,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                label: 'Plan Oluştur',
                onTap: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  final plan = await SupabaseService.createWorkoutPlan(
                    clientId: widget.clientProfile['id'].toString(),
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    weekDay: selectedDay,
                  );
                  _showSuccess('Plan oluşturuldu! Şimdi egzersiz ekleyebilirsiniz.');
                  await _loadAll();
                  // Plan oluşturulduktan sonra egzersiz ekle sayfasına yönlendir
                  if (mounted) _showAddExerciseSheet(plan['id'].toString());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Egzersiz Ekleme ───────────────────────────────────────────────────────
  void _showAddExerciseSheet(String planId) {
    String selectedCat = 'Güç / Ağırlık';
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');
    final durationCtrl = TextEditingController();
    final restCtrl = TextEditingController(text: '60');
    final notesCtrl = TextEditingController();

    // Popüler egzersiz önerileri
    const suggestions = {
      'Güç / Ağırlık': ['Bench Press', 'Squat', 'Deadlift', 'Shoulder Press', 'Pull-up', 'Barbell Row', 'Leg Press', 'Dumbbell Curl', 'Triceps Pushdown'],
      'Kardio': ['Koşu Bandı', 'Bisiklet', 'Eliptik', 'Yürüyüş', 'İp Atlama'],
      'HIIT': ['Burpee', 'Jump Squat', 'Mountain Climber', 'Box Jump', 'Kettlebell Swing'],
      'Esneklik': ['Hamstring Stretch', 'Hip Flexor', 'Shoulder Stretch', 'Cat-Cow', 'Pigeon Pose'],
      'Fonksiyonel': ['Plank', 'Bear Crawl', 'Farmer Walk', 'Battle Rope', 'TRX Row'],
      'Serbest': [],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final catData = _exerciseCategories.firstWhere((c) => c.label == selectedCat);
          final isCardio = selectedCat == 'Kardio';

          return _BottomSheet(
            title: 'Egzersiz Ekle',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori seçimi
                const Text('Hareket Türü', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _exerciseCategories.map((c) {
                      final sel = c.label == selectedCat;
                      return GestureDetector(
                        onTap: () => setSheet(() => selectedCat = c.label),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? c.color : c.color.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(children: [
                            Icon(c.icon, color: sel ? Colors.white : c.color, size: 14),
                            const SizedBox(width: 6),
                            Text(c.label,
                                style: TextStyle(
                                  color: sel ? Colors.white : c.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // Egzersiz adı + öneriler
                const Text('Egzersiz', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _SheetField(ctrl: nameCtrl, label: 'Egzersiz Adı', hint: 'ör. Bench Press'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (suggestions[selectedCat] ?? []).map((s) {
                    return GestureDetector(
                      onTap: () => setSheet(() => nameCtrl.text = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: catData.color.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: catData.color.withAlpha(40)),
                        ),
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 11,
                                color: catData.color,
                                fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Set/Rep veya Süre
                if (!isCardio) ...[
                  Row(children: [
                    Expanded(child: _SheetField(ctrl: setsCtrl, label: 'Set', hint: '3', isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _SheetField(ctrl: repsCtrl, label: 'Tekrar (Rep)', hint: '12', isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _SheetField(ctrl: restCtrl, label: 'Dinlenme (sn)', hint: '60', isNumber: true)),
                  ]),
                ] else ...[
                  Row(children: [
                    Expanded(child: _SheetField(ctrl: durationCtrl, label: 'Süre (dakika)', hint: '20', isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _SheetField(ctrl: restCtrl, label: 'Dinlenme (sn)', hint: '30', isNumber: true)),
                  ]),
                ],
                const SizedBox(height: 12),
                _SheetField(ctrl: notesCtrl, label: 'Koç Notu (opsiyonel)', hint: 'Teknik ipucu, açıklama...', maxLines: 2),
                const SizedBox(height: 20),
                _PrimaryButton(
                  label: 'Egzersiz Ekle',
                  color: catData.color,
                  onTap: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await SupabaseService.addExerciseToPlan(
                      planId: planId,
                      name: nameCtrl.text.trim(),
                      category: selectedCat,
                      sets: int.tryParse(setsCtrl.text) ?? 3,
                      reps: int.tryParse(repsCtrl.text) ?? 12,
                      durationSec: isCardio
                          ? (int.tryParse(durationCtrl.text) ?? 20) * 60
                          : null,
                      restSec: int.tryParse(restCtrl.text) ?? 60,
                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    );
                    await _loadAll();
                    _showSuccess('Egzersiz eklendi ✅');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Beslenme Planı Ekleme ─────────────────────────────────────────────────
  void _showAddMealPlanSheet() {
    String selectedTime = 'Kahvaltı';
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final protCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _BottomSheet(
          title: 'Beslenme Planına Öğün Ekle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Öğün Zamanı', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _mealTimes.map((t) {
                  final sel = selectedTime == t;
                  return GestureDetector(
                    onTap: () => setSheet(() => selectedTime = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? const Color(0xFFFF6B35) : const Color(0xFFFF6B35).withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(t,
                          style: TextStyle(
                            color: sel ? Colors.white : const Color(0xFFFF6B35),
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              _SheetField(ctrl: nameCtrl, label: 'Öğün / Yiyecek', hint: 'ör. Tavuk Göğsü + Pirinç'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _SheetField(ctrl: calCtrl, label: 'Kalori', hint: '400', isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _SheetField(ctrl: protCtrl, label: 'Protein (g)', hint: '35', isNumber: true)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _SheetField(ctrl: carbCtrl, label: 'Karbonhidrat (g)', hint: '50', isNumber: true)),
                const SizedBox(width: 10),
                Expanded(child: _SheetField(ctrl: fatCtrl, label: 'Yağ (g)', hint: '10', isNumber: true)),
              ]),
              const SizedBox(height: 12),
              _SheetField(ctrl: notesCtrl, label: 'Notlar (opsiyonel)', hint: 'Pişirme yöntemi, alternatifler...', maxLines: 2),
              const SizedBox(height: 20),
              _PrimaryButton(
                label: 'Öğünü Plana Ekle',
                color: const Color(0xFFFF6B35),
                onTap: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await SupabaseService.addNutritionPlanItem(
                    clientId: widget.clientProfile['id'].toString(),
                    mealTime: selectedTime,
                    mealName: nameCtrl.text.trim(),
                    targetCalories: int.tryParse(calCtrl.text),
                    targetProtein: double.tryParse(protCtrl.text),
                    targetCarbs: double.tryParse(carbCtrl.text),
                    targetFat: double.tryParse(fatCtrl.text),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  await _loadAll();
                  _showSuccess('Öğün plana eklendi ✅');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Not Ekleme ────────────────────────────────────────────────────────────
  void _showAddNoteSheet() {
    String selectedCat = 'genel';
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => _BottomSheet(
          title: 'Not Ekle',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kategori', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: _noteCategories.map((nc) {
                  final sel = selectedCat == nc.value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => selectedCat = nc.value),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? nc.color : nc.color.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(children: [
                          Icon(nc.icon, color: sel ? Colors.white : nc.color, size: 18),
                          const SizedBox(height: 4),
                          Text(nc.label,
                              style: TextStyle(
                                color: sel ? Colors.white : nc.color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              )),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Danışanınız için notunuzu yazın...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                label: 'Notu Kaydet',
                onTap: () async {
                  if (noteCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  await SupabaseService.addCoachNote(
                    clientId: widget.clientProfile['id'].toString(),
                    note: noteCtrl.text.trim(),
                    category: selectedCat,
                  );
                  await _loadAll();
                  _showSuccess('Not kaydedildi ✅');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.clientProfile;
    final consumed = _todayMeals.fold<int>(0, (s, m) => s + m.calories);
    final remaining = _currentTdee - consumed;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: Colors.white,
            leading: BackButton(color: AppColors.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (profile['kalori_id'] ?? '?').toString().substring(0, 1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KaloriID: ${profile['kalori_id'] ?? '-'}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18),
                          ),
                          Text(
                            '${profile['age'] ?? '-'} yaş • ${profile['weight'] ?? '-'} kg • ${profile['height'] ?? '-'} cm',
                            style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            _HeaderChip('$consumed kcal yendi', Icons.restaurant),
                            const SizedBox(width: 8),
                            _HeaderChip(
                                '${remaining >= 0 ? remaining : 0} kcal kaldı',
                                Icons.local_fire_department),
                          ]),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showEditGoalsDialog,
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(text: 'Bugün'),
                Tab(text: 'Antrenman'),
                Tab(text: 'Beslenme'),
                Tab(text: 'Notlar'),
              ],
            ),
          ),
        ],
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildTodayTab(consumed),
                  _buildWorkoutTab(),
                  _buildNutritionTab(),
                  _buildNotesTab(),
                ],
              ),
      ),
    );
  }

  // ── Bugün Sekmesi ─────────────────────────────────────────────────────────
  Widget _buildTodayTab(int consumed) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kalori özet kartları
          Row(children: [
            Expanded(child: _StatCard(
              label: 'Günlük Limit',
              value: '$_currentTdee kcal',
              icon: Icons.flag_outlined,
              color: AppColors.primary,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Tüketilen',
              value: '$consumed kcal',
              icon: Icons.restaurant,
              color: const Color(0xFFFF6B35),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _StatCard(
              label: 'Kalan',
              value: '${(_currentTdee - consumed).clamp(0, 9999)} kcal',
              icon: Icons.local_fire_department,
              color: consumed > _currentTdee ? AppColors.danger : AppColors.secondary,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'Adım Hedefi',
              value: '$_stepTarget adım',
              icon: Icons.directions_walk,
              color: const Color(0xFF8B5CF6),
            )),
          ]),
          const SizedBox(height: 20),
          // İlerleme çubuğu
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kalori İlerlemesi', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  Text('${((consumed / _currentTdee) * 100).clamp(0, 100).round()}%',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (consumed / _currentTdee).clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  color: consumed > _currentTdee ? AppColors.danger : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('BUGÜNKÜ ÖĞÜNLER',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_todayMeals.isEmpty)
            _EmptyCard(icon: Icons.no_food, label: 'Henüz öğün girilmemiş')
          else
            ..._todayMeals.map((m) => _MealCard(meal: m)),
        ],
      ),
    );
  }

  // ── Antrenman Sekmesi ─────────────────────────────────────────────────────
  Widget _buildWorkoutTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ANTRENMAN PLANLARI',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            GestureDetector(
              onTap: _showCreatePlanSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Yeni Plan', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_workoutPlans.isEmpty)
          _EmptyCard(icon: Icons.fitness_center, label: 'Henüz antrenman planı yok\nYukarıdan plan oluşturun')
        else
          ..._workoutPlans.map((plan) => _WorkoutPlanCard(
            plan: plan,
            onAddExercise: () => _showAddExerciseSheet(plan['id'].toString()),
            onDeletePlan: () async {
              await SupabaseService.deleteWorkoutPlan(plan['id'].toString());
              _loadAll();
            },
            onDeleteExercise: (exId) async {
              await SupabaseService.deleteExercise(exId);
              _loadAll();
            },
          )),
      ],
    );
  }

  // ── Beslenme Sekmesi ──────────────────────────────────────────────────────
  Widget _buildNutritionTab() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in _nutritionPlan) {
      final t = item['meal_time'] ?? 'Diğer';
      grouped.putIfAbsent(t, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('BESLENME PLANI',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            GestureDetector(
              onTap: _showAddMealPlanSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF4D6D)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Öğün Ekle', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_nutritionPlan.isEmpty)
          _EmptyCard(icon: Icons.restaurant_menu, label: 'Henüz beslenme planı yok\nYukarıdan öğün ekleyin')
        else
          ...grouped.entries.map((e) => _NutritionGroupCard(
            mealTime: e.key,
            items: e.value,
            onDelete: (id) async {
              await SupabaseService.deleteNutritionPlanItem(id);
              _loadAll();
            },
          )),
      ],
    );
  }

  // ── Notlar Sekmesi ────────────────────────────────────────────────────────
  Widget _buildNotesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('KOÇ NOTLARI',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            GestureDetector(
              onTap: _showAddNoteSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.coolGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Not Ekle', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_coachNotes.isEmpty)
          _EmptyCard(icon: Icons.notes, label: 'Henüz not yok\nDanışanınız için notlar ekleyin')
        else
          ..._coachNotes.map((n) => _NoteCard(
            note: n,
            onDelete: () async {
              await SupabaseService.deleteCoachNote(n['id'].toString());
              _loadAll();
            },
          )),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Yardımcı Widget'lar
// ────────────────────────────────────────────────────────────────────────────

class _HeaderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _HeaderChip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white70, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      ]),
    );
  }
}

class _MealCard extends StatelessWidget {
  final MealLog meal;
  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (meal.protein != null)
            Text('P: ${meal.protein?.toStringAsFixed(0)}g • K: ${meal.carbs?.toStringAsFixed(0)}g • Y: ${meal.fat?.toStringAsFixed(0)}g',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${meal.calories}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFF6B35))),
          const Text('kcal', style: TextStyle(color: AppColors.textHint, fontSize: 10)),
        ]),
      ]),
    );
  }
}

class _WorkoutPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onAddExercise;
  final VoidCallback onDeletePlan;
  final void Function(String) onDeleteExercise;

  const _WorkoutPlanCard({
    required this.plan,
    required this.onAddExercise,
    required this.onDeletePlan,
    required this.onDeleteExercise,
  });

  @override
  Widget build(BuildContext context) {
    final exercises = (plan['workout_exercises'] as List?) ?? [];
    final weekDay = plan['week_day'];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Plan header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan['title'] ?? 'Plan',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              if (weekDay != null)
                Text(weekDay, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 11)),
            ])),
            // Egzersiz ekle
            GestureDetector(
              onTap: onAddExercise,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Egzersiz', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Plan sil
            GestureDetector(
              onTap: onDeletePlan,
              child: const Icon(Icons.delete_outline, color: Colors.white60, size: 20),
            ),
          ]),
        ),
        // Egzersizler
        if (exercises.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Henüz egzersiz yok. Sağ üstten ekleyin.',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          )
        else
          ...exercises.asMap().entries.map((entry) {
            final i = entry.key;
            final ex = entry.value as Map<String, dynamic>;
            final isCardio = ex['duration_sec'] != null;
            final catColor = _ClientDetailScreenState._exerciseCategories
                .firstWhere((c) => c.label == (ex['category'] ?? ''), orElse: () => const _ExCat('', Icons.circle, AppColors.textSecondary))
                .color;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(children: [
                // Sıra numarası
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: TextStyle(color: catColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ex['name'] ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    isCardio
                        ? '${((ex['duration_sec'] ?? 0) / 60).round()} dk • ${ex['rest_sec'] ?? 60}sn dinlenme'
                        : '${ex['sets'] ?? 3} set × ${ex['reps'] ?? 12} tekrar • ${ex['rest_sec'] ?? 60}sn dinlenme',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  if (ex['notes'] != null)
                    Text('💬 ${ex['notes']}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 10)),
                ])),
                GestureDetector(
                  onTap: () => onDeleteExercise(ex['id'].toString()),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textHint),
                ),
              ]),
            );
          }),
      ]),
    );
  }
}

class _NutritionGroupCard extends StatelessWidget {
  final String mealTime;
  final List<Map<String, dynamic>> items;
  final void Function(String) onDelete;

  const _NutritionGroupCard({required this.mealTime, required this.items, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final totalCal = items.fold<int>(0, (s, i) => s + ((i['target_calories'] as num?)?.toInt() ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFFF6B35),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(mealTime, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('~$totalCal kcal', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['meal_name'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(
                [
                  if (item['target_calories'] != null) '${item['target_calories']} kcal',
                  if (item['target_protein'] != null) 'P: ${item['target_protein']}g',
                  if (item['target_carbs'] != null) 'K: ${item['target_carbs']}g',
                  if (item['target_fat'] != null) 'Y: ${item['target_fat']}g',
                ].join(' • '),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              if (item['notes'] != null)
                Text('💬 ${item['notes']}', style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
            ])),
            GestureDetector(
              onTap: () => onDelete(item['id'].toString()),
              child: const Icon(Icons.close, size: 16, color: AppColors.textHint),
            ),
          ]),
        )),
      ]),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onDelete});

  static const _catColors = {
    'genel': AppColors.primary,
    'beslenme': Color(0xFFFF6B35),
    'antrenman': Color(0xFF3D5AF1),
    'motivasyon': Color(0xFFFFB347),
  };

  static const _catIcons = {
    'genel': Icons.notes,
    'beslenme': Icons.restaurant,
    'antrenman': Icons.fitness_center,
    'motivasyon': Icons.star,
  };

  @override
  Widget build(BuildContext context) {
    final cat = note['category'] ?? 'genel';
    final color = _catColors[cat] ?? AppColors.primary;
    final icon = _catIcons[cat] ?? Icons.notes;
    final date = DateTime.tryParse(note['created_at'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 6)],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(note['note'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: const TextStyle(color: AppColors.textHint, fontSize: 10),
            ),
          ],
        ])),
        GestureDetector(
          onTap: onDelete,
          child: const Icon(Icons.delete_outline, size: 18, color: AppColors.textHint),
        ),
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Icon(icon, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
      ]),
    );
  }
}

// ── Ortak Bottom Sheet Sarmalayıcı ───────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          child,
        ]),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final int maxLines;
  final bool isNumber;

  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _PrimaryButton({required this.label, required this.onTap, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── Veri Tipleri ──────────────────────────────────────────────────────────────
class _ExCat {
  final String label;
  final IconData icon;
  final Color color;
  const _ExCat(this.label, this.icon, this.color);
}

class _NoteCat {
  final String label;
  final IconData icon;
  final Color color;
  String get value => label.toLowerCase();
  const _NoteCat(this.label, this.icon, this.color);
}
