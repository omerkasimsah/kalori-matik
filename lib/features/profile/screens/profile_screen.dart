import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/calorie_calculator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/calorie_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Supabase'den çekilen kullanıcı bilgilerini (yaş, kilo, hedef vs) tutan bellek
  Map<String, dynamic>? _profile;
  // Ağ isteği atılırken ekranda loading göstermek için
  bool _isLoading = true;
  // Profil düzenleme (Edit) modunun açık olup olmadığını kontrol eder
  bool _isEditing = false;

  // Bilgi düzenleme form alanlarının (TextField) denetleyicileri
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _targetWeightLossCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  
  // Ana Hedef (Kilo Al, Ver, Koru vb.)
  String _goal = 'maintain';
  // Kaydet butonuna basıldığında çift tıklamayı engellemek için yükleme bayrağı
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Önizleme yenile
    _targetWeightLossCtrl.addListener(_onLossInputChanged);
    _daysCtrl.addListener(_onLossInputChanged);
  }

  void _onLossInputChanged() => setState(() {});

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _targetWeightLossCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.getProfile();
      if (mounted) {
        setState(() => _profile = data);
        if (data != null) {
          _weightCtrl.text = (data['weight'] ?? '').toString();
          _heightCtrl.text = (data['height'] ?? '').toString();
          _goal = data['goal'] ?? 'maintain';
          _targetWeightLossCtrl.text =
              (data['target_weight_loss'] ?? '').toString();
          _daysCtrl.text = (data['target_days'] ?? '').toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  // Kullanıcı profili düzenlerken anlık olarak (canlı) yeni TDEE limitini önizlemek için
  // Mifflin-St Jeor formülünü mevcut yazılmış veriler üzerinden tekrar lokal hesaplar
  int _computeTdee() {
    final weight =
        double.tryParse(_weightCtrl.text) ?? (_profile?['weight'] as num?)?.toDouble() ?? 70;
    final height =
        double.tryParse(_heightCtrl.text) ?? (_profile?['height'] as num?)?.toDouble() ?? 170;
    final age = (_profile?['age'] as num?)?.toInt() ?? 25;
    final isMale = (_profile?['gender'] ?? 'Erkek') == 'Erkek';
    final activityLevel =
        (_profile?['activity_level'] as num?)?.toDouble() ?? 1.375;

    final bmr = isMale
        ? (10 * weight + 6.25 * height - 5 * age + 5)
        : (10 * weight + 6.25 * height - 5 * age - 161);
    return (bmr * activityLevel).round();
  }

  // Kilo verme hedefine göre önerilen günlük kalori
  int? _previewCalorie() {
    if (_goal != 'lose') return null;
    final kg = double.tryParse(_targetWeightLossCtrl.text);
    final days = int.tryParse(_daysCtrl.text);
    if (kg == null || days == null || kg <= 0 || days <= 0) return null;
    return CalorieCalculator.calculateWeightLossCalorie(
      tdee: _computeTdee(),
      targetWeightLoss: kg,
      days: days,
    );
  }

  // Edilen form bilgilerini Supabase API aracılığıyla kalıcı veritabanına aktarma
  // DÜZELTME: Mevcut profil verisini merge ederek gönderir — kalori_id/role gibi
  // kritik alanlar üzerine yazılmaz.
  Future<void> _saveProfile() async {
    if (_profile == null) return;
    setState(() => _isSaving = true);
    try {
      final weight = double.tryParse(_weightCtrl.text) ?? (_profile!['weight'] as num?)?.toDouble() ?? 70;
      final height = double.tryParse(_heightCtrl.text) ?? (_profile!['height'] as num?)?.toDouble() ?? 170;
      final age = _profile!['age'] ?? 25;
      final isMale = (_profile!['gender'] ?? 'Erkek') == 'Erkek';
      final activityLevel =
          (_profile!['activity_level'] as num?)?.toDouble() ?? 1.375;

      final bmr = isMale
          ? (10 * weight + 6.25 * height - 5 * age + 5)
          : (10 * weight + 6.25 * height - 5 * age - 161);
      int tdee = (bmr * activityLevel).round();

      // Kilo verme hedefi girildiyse hassas hesap yap
      final targetKg = double.tryParse(_targetWeightLossCtrl.text);
      final targetDays = int.tryParse(_daysCtrl.text);

      if (_goal == 'lose' &&
          targetKg != null &&
          targetKg > 0 &&
          targetDays != null &&
          targetDays > 0) {
        tdee = CalorieCalculator.calculateWeightLossCalorie(
          tdee: tdee,
          targetWeightLoss: targetKg,
          days: targetDays,
        );
      } else if (_goal == 'lose') {
        tdee -= 500;
      } else if (_goal == 'gain') {
        tdee += 500;
      }

      // Mevcut profil verisiyle merge et — kritik alanlar (kalori_id, role) korunur
      final updatedProfile = {
        ..._profile!,                  // mevcut tüm alanları koru
        'weight': weight,
        'height': height,
        'goal': _goal,
        'daily_tdee': tdee,
        'target_weight_loss': (_goal == 'lose' && targetKg != null) ? targetKg : null,
        'target_days': (_goal == 'lose' && targetDays != null) ? targetDays : null,
      };

      await SupabaseService.saveProfile(updatedProfile);

      // Provider'ı güncelle
      ref.read(dailyBudgetProvider.notifier).state = tdee;
      ref.read(mealLogsProvider.notifier).loadUserBudget();

      if (mounted) {
        setState(() {
          _isEditing = false;
          _profile = updatedProfile;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil güncellendi ✅'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt hatası: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _goalLabel(String? goal) {
    switch (goal) {
      case 'lose':
        return 'Kilo Vermek 📉';
      case 'gain':
        return 'Kilo Almak 📈';
      default:
        return 'Kilomu Korumak ⚖️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.getCurrentUser();
    final budget = ref.watch(dailyBudgetProvider);
    final preview = _previewCalorie();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Başlık ──────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Profilim',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary),
                      ),
                      if (!_isEditing)
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit_outlined,
                              size: 16, color: AppColors.primary),
                          label: const Text('Düzenle',
                              style: TextStyle(color: AppColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Avatar, Email & KaloriID ────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(80),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 34),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.email?.split('@').first ?? 'Kullanıcı',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    user?.email ?? '',
                                    style: TextStyle(
                                        color: Colors.white.withAlpha(180),
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // ── KaloriID Chip ──────────────────────────────────
                        if (_profile?['kalori_id'] != null) ...[
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: _profile!['kalori_id'].toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('KaloriID kopyalandı 📋'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: Colors.white.withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code,
                                          color: Colors.white70, size: 16),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'KaloriID',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _profile!['kalori_id'].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Icon(Icons.copy,
                                      color: Colors.white60, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Günlük Kalori Limiti ─────────────────────────────────
                  Container(
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_fire_department,
                              color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Günlük Kalori Limitin',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                              Text(
                                '$budget kcal',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Profil Bilgileri ─────────────────────────────────────
                  Container(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Fiziksel Bilgiler',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        if (_isEditing) ...[
                          // Düzenleme modu
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _weightCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Kilo (kg)',
                                    prefixIcon: Icon(
                                        Icons.monitor_weight_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _heightCtrl,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Boy (cm)',
                                    prefixIcon: Icon(Icons.height),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Hedef',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          const SizedBox(height: 8),
                          _GoalSelector(
                              selected: _goal,
                              onChanged: (v) =>
                                  setState(() => _goal = v)),

                          // ── Kilo Verme Hedef Alanı ──────────────────
                          if (_goal == 'lose') ...[
                            const SizedBox(height: 20),
                            _WeightLossTargetCard(
                              targetWeightLossCtrl: _targetWeightLossCtrl,
                              daysCtrl: _daysCtrl,
                              previewCalorie: preview,
                            ),
                          ],

                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _isEditing = false),
                                  child: const Text('İptal'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isSaving ? null : _saveProfile,
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Text('Kaydet'),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Görüntüleme modu
                          _ProfileRow(
                              icon: Icons.cake_outlined,
                              label: 'Yaş',
                              value:
                                  '${_profile?['age'] ?? '-'} yaş'),
                          _ProfileRow(
                              icon: Icons.person_outline,
                              label: 'Cinsiyet',
                              value: _profile?['gender'] ?? '-'),
                          _ProfileRow(
                              icon: Icons.height,
                              label: 'Boy',
                              value:
                                  '${(_profile?['height'] as num?)?.toStringAsFixed(0) ?? '-'} cm'),
                          _ProfileRow(
                              icon: Icons.monitor_weight_outlined,
                              label: 'Kilo',
                              value:
                                  '${(_profile?['weight'] as num?)?.toStringAsFixed(1) ?? '-'} kg'),
                          _ProfileRow(
                              icon: Icons.flag_outlined,
                              label: 'Hedef',
                              value: _goalLabel(_profile?['goal'])),
                          // Kilo verme hedefi bilgileri
                          if (_profile?['goal'] == 'lose' &&
                              _profile?['target_weight_loss'] != null &&
                              _profile?['target_days'] != null) ...[
                            const Divider(height: 24),
                            _WeightLossInfoCard(
                              targetWeightLoss: (_profile!['target_weight_loss'] as num).toDouble(),
                              targetDays: (_profile!['target_days'] as num).toInt(),
                              dailyCalorie: (_profile?['daily_tdee'] as num?)?.toInt() ?? 0,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Çıkış Yap ──────────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: () async {
                      await SupabaseService.signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    label: const Text('Çıkış Yap',
                        style: TextStyle(color: AppColors.danger)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
      ),
    );
  }
}

// ── Kilo Verme Hedef Giriş Kartı (Düzenleme Modunda) ─────────────────────────

class _WeightLossTargetCard extends StatelessWidget {
  final TextEditingController targetWeightLossCtrl;
  final TextEditingController daysCtrl;
  final int? previewCalorie;

  const _WeightLossTargetCard({
    required this.targetWeightLossCtrl,
    required this.daysCtrl,
    required this.previewCalorie,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2ECC71).withAlpha(20),
            const Color(0xFF27AE60).withAlpha(10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withAlpha(60),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_down,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Kilo Verme Hedefin',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: targetWeightLossCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Vermek istediğin kilo',
                    hintText: 'ör. 5',
                    suffixText: 'kg',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppColors.primary.withAlpha(40))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Süre',
                    hintText: 'ör. 60',
                    suffixText: 'gün',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: AppColors.primary.withAlpha(40))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          if (previewCalorie != null) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Önerilen günlük kalori: $previewCalorie kcal',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '* Maksimum 1000 kcal/gün kalori açığı uygulanır.',
              style: TextStyle(
                  fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Kilo Verme Hedef Bilgi Kartı (Görüntüleme Modunda) ───────────────────────

class _WeightLossInfoCard extends StatelessWidget {
  final double targetWeightLoss;
  final int targetDays;
  final int dailyCalorie;

  const _WeightLossInfoCard({
    required this.targetWeightLoss,
    required this.targetDays,
    required this.dailyCalorie,
  });

  @override
  Widget build(BuildContext context) {
    final weeks = (targetDays / 7).ceil();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2ECC71).withAlpha(15),
            const Color(0xFF27AE60).withAlpha(8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.primary.withAlpha(50), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.trending_down,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Kilo Verme Planın',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.monitor_weight_outlined,
                label: 'Hedef',
                value: '${targetWeightLoss.toStringAsFixed(1)} kg',
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.calendar_today_outlined,
                label: 'Süre',
                value: '$targetDays gün (~$weeks hafta)',
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoChip(
            icon: Icons.local_fire_department,
            label: 'Günlük hedef',
            value: '$dailyCalorie kcal',
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: chip) : Expanded(child: chip);
  }
}

// ── Yardımcı Bileşenler ───────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

class _GoalSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GoalSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('lose', 'Kilo Ver 📉'),
      ('maintain', 'Koru ⚖️'),
      ('gain', 'Kilo Al 📈'),
    ];
    return Row(
      children: options.map((o) {
        final isSelected = selected == o.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withAlpha(30)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2),
                ),
                child: Text(o.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
