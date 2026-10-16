import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../../core/services/supabase_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Karşılama ekranları arası kaydırmalı geçiş (Slide) denetleyicisi
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // ── Kullanıcı Verileri State (Geçici Hafıza) ──
  // Uygulamaya kayıtlanacak kullanıcının Rol Tabanlı Kimliği
  String _role = 'client'; // client (Danışan), coach (Koç), dietitian (Diyetisyen)
  bool _isMale = true;
  double _weight = 70.0;
  double _height = 175.0;
  int _age = 25;
  
  // Hedef Durumu ('lose', 'gain', 'maintain')
  String _goal = 'maintain';
  
  // Hareket Katsayısı (TDEE hesaplamasında çarpan olarak kullanılır)
  double _activityLevel = 1.375; // Varsayılan: Hafif Hareketli


  void _nextPage() {
    // Danışan olmayan profesyoneller (Koç/Diyetisyen) fiziksel ölçüm adımlarını atlar (Early Exit).
    if (_currentIndex == 0 && (_role == 'coach' || _role == 'dietitian')) {
      _finishOnboarding();
      return;
    }

    if (_currentIndex < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    // Sadece danışanlar için metrikler hesaplanır.
    int target = 0;
    if (_role == 'client') {
      final bmr = CalorieCalculator.calculateBMR(
        weight: _weight,
        height: _height,
        age: _age,
        isMale: _isMale,
      );
      final tdee = CalorieCalculator.calculateTDEE(
        bmr: bmr,
        activityLevel: _activityLevel,
      );
      target = CalorieCalculator.calculateDailyTarget(
        tdee: tdee,
        goal: _goal,
      );
    }

    // 2. ADIM: Eşsiz KaloriID üretimi (karışabilecek 0/O, 1/I harfleri hariç).
    // Veritabanında trigger varsa o da kimlik atayabilir; unique kısıtı çakışmayı engeller.
    String? kaloriId;
    if (_role == 'client') {
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final rnd = Random.secure();
      kaloriId = List.generate(6, (_) => alphabet[rnd.nextInt(alphabet.length)])
          .join();
    }

    // 3. ADIM: Veritabanına Yansıtma (Persistence)
    try {
      if (_role == 'client') {
        await SupabaseService.saveProfile({
          'role': _role,
          'kalori_id': kaloriId,
          'age': _age,
          'gender': _isMale ? 'Erkek' : 'Kadın',
          'height': _height,
          'weight': _weight,
          'activity_level': _activityLevel,
          'goal': _goal,
          'daily_tdee': target,
        });
      } else {
        await SupabaseService.saveProfile({
          'role': _role,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Profil kaydedilemedi. İnternet bağlantınızı kontrol edip tekrar deneyin.',
                style: TextStyle(color: AppColors.danger)),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // 4. ADIM: Finansal Metafor Bildirimi ve Yönlendirme
    if (_role == 'client') {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Bankan Hazır! 🎉', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Günlük Harcama Limitin:', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                '$target KCAL',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/home');
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Kabul Ediyorum, Başla'),
            ),
          ],
        ),
      );
    } else {
      // Profesyoneller için vizyoner karşılama
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Profesyonel Panel Hazır 💼', textAlign: TextAlign.center),
          content: const Text(
            'Zaman ve emek yönetimi modülleriniz bağlandı. Danışanlarınızı Kalori ID numaraları ile eklemeye hemen başlayabilirsiniz.',
            textAlign: TextAlign.center,
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/home');
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Panele Geçiş Yap'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adım ${_currentIndex + 1} / 6'),
        leading: _currentIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / 6,
              backgroundColor: AppColors.cardSurface,
              color: AppColors.primary,
              minHeight: 8,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  // Step 0: Role Selection
                  _buildRoleStep(),
                  // Step 1: Gender
                  _buildGenderStep(),
                  // Step 2: Age
                  _buildAgeStep(),
                  // Step 3: Height & Weight
                  _buildBodyMetricsStep(),
                  // Step 4: Activity Level
                  _buildActivityStep(),
                  // Step 5: Goal
                  _buildGoalStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(_currentIndex == 5 ? 'Tamamla' : 'İleri'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Uygulamayı Hangi Amaçla Kullanacaksınız?', 
               style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
               textAlign: TextAlign.center),
          const SizedBox(height: 32),
          _ListOption(
            title: 'Danışan (Kişisel Profil)',
            subtitle: 'Kendi hedeflerime ulaşmak istiyorum',
            isSelected: _role == 'client',
            onTap: () => setState(() => _role = 'client'),
          ),
          _ListOption(
            title: 'Spor Koçu',
            subtitle: 'Danışanlarımın performansını takip edeceğim',
            isSelected: _role == 'coach',
            onTap: () => setState(() => _role = 'coach'),
          ),
          _ListOption(
            title: 'Diyetisyen',
            subtitle: 'Danışanlarımın beslenmesini planlayacağım',
            isSelected: _role == 'dietitian',
            onTap: () => setState(() => _role = 'dietitian'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Cinsiyetiniz Nedir?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _SelectionCard(
                  title: 'Erkek',
                  icon: Icons.male,
                  isSelected: _isMale,
                  onTap: () => setState(() => _isMale = true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SelectionCard(
                  title: 'Kadın',
                  icon: Icons.female,
                  isSelected: !_isMale,
                  onTap: () => setState(() => _isMale = false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Kaç Yaşındasınız?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),
          Text(
            '$_age',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 64),
          ),
          Slider(
            value: _age.toDouble(),
            min: 12,
            max: 100,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _age = val.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMetricsStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Boy ve Kilonuz?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Boy (cm):', style: Theme.of(context).textTheme.titleMedium),
              Text('${_height.toInt()} cm', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
            ],
          ),
          Slider(
            value: _height,
            min: 120,
            max: 220,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _height = val),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kilo (kg):', style: Theme.of(context).textTheme.titleMedium),
              Text('${_weight.toInt()} kg', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
            ],
          ),
          Slider(
            value: _weight,
            min: 30,
            max: 150,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _weight = val),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Aktivite Seviyeniz?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),
          _ListOption(
            title: 'Hareketsiz',
            subtitle: 'Masa başı iş, az egzersiz',
            isSelected: _activityLevel == 1.2,
            onTap: () => setState(() => _activityLevel = 1.2),
          ),
          _ListOption(
            title: 'Hafif Aktif',
            subtitle: 'Haftada 1-3 gün hafif egzersiz',
            isSelected: _activityLevel == 1.375,
            onTap: () => setState(() => _activityLevel = 1.375),
          ),
          _ListOption(
            title: 'Orta Aktif',
            subtitle: 'Haftada 3-5 gün orta egzersiz',
            isSelected: _activityLevel == 1.55,
            onTap: () => setState(() => _activityLevel = 1.55),
          ),
          _ListOption(
            title: 'Çok Aktif',
            subtitle: 'Haftada 6-7 gün ağır egzersiz',
            isSelected: _activityLevel == 1.725,
            onTap: () => setState(() => _activityLevel = 1.725),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Hedefiniz Nedir?', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),
          _ListOption(
            title: 'Kilo Vermek',
            subtitle: 'Kalori açığı oluşturur (-500 kcal)',
            isSelected: _goal == 'lose',
            onTap: () => setState(() => _goal = 'lose'),
          ),
          _ListOption(
            title: 'Kilomu Korumak',
            subtitle: 'Mevcut durumu korur',
            isSelected: _goal == 'maintain',
            onTap: () => setState(() => _goal = 'maintain'),
          ),
          _ListOption(
            title: 'Kilo Almak / Kas Yapmak',
            subtitle: 'Kalori fazlası oluşturur (+500 kcal)',
            isSelected: _goal == 'gain',
            onTap: () => setState(() => _goal = 'gain'),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class _SelectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(50) : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ListOption({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? AppColors.primary.withAlpha(20) : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
