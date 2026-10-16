import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../activity/screens/activity_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../stats/screens/stats_screen.dart';
import '../../tracking/screens/tracking_screen.dart';
import '../models/meal_log.dart';
import '../providers/calorie_provider.dart';
import '../providers/water_provider.dart';
import '../widgets/calorie_circular_indicator.dart';
import '../widgets/macro_progress_card.dart';
import '../widgets/meal_editor_sheet.dart';
import '../widgets/meal_list_item.dart';
import '../widgets/water_card.dart';
import 'professional_dashboard.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  // Alt navigasyon barında aktif olan sekmenin indeks numarası
  int _selectedIndex = 0;

  // Tüm sekmeler bellekte tutulur (IndexedStack)
  static const List<Widget> _screens = [
    _CalorieDashboard(), // Sekme 1: Kalori
    ActivityScreen(),    // Sekme 2: Aktivite
    StatsScreen(),       // Sekme 3: İstatistik
    ProfileScreen(),     // Sekme 4: Profil
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Uygulama gece yarısından sonra tekrar açıldığında günlük verileri yenile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(mealLogsProvider.notifier).refreshIfNewDay();
      ref.read(waterIntakeProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off,
                    size: 56, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text('Profil yüklenemedi',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text('İnternet bağlantınızı kontrol edip tekrar deneyin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (profile) {
        // Profil yoksa kullanıcı onboarding'i tamamlamamış demektir.
        if (profile == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (SupabaseService.getCurrentUser() == null) {
              context.go('/login');
            } else {
              context.go('/onboarding');
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Rol tabanlı yönlendirme — Koç veya Diyetisyen ise ayrı panel
        final role = profile['role'];
        if (role == 'coach' || role == 'dietitian') {
          return const ProfessionalDashboard();
        }

        // ── Danışan / Normal Kullanıcı Arayüzü ───────────────────────────
        return Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              tooltip: 'Öğün ekle',
              onPressed: () => context.push('/add-meal'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const CircleBorder(),
              child: Icon(Icons.add_a_photo_outlined,
                  size: 26, color: AppColors.background),
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: AppColors.cardSurface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Ana Sayfa',
                    isSelected: _selectedIndex == 0,
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                  _NavItem(
                    icon: Icons.directions_run_rounded,
                    label: 'Aktivite',
                    isSelected: _selectedIndex == 1,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                  const SizedBox(width: 56), // FAB boşluğu
                  _NavItem(
                    icon: Icons.insights_rounded,
                    label: 'İstatistik',
                    isSelected: _selectedIndex == 2,
                    onTap: () => setState(() => _selectedIndex = 2),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profil',
                    isSelected: _selectedIndex == 3,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ana Sayfa İçeriği (Dashboard) ─────────────────────────────────────────────

class _CalorieDashboard extends ConsumerWidget {
  const _CalorieDashboard();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  Future<void> _editMeal(
      BuildContext context, WidgetRef ref, MealLog meal) async {
    final draft = await showMealEditorSheet(
      context,
      title: 'Öğünü düzenle',
      confirmLabel: 'Güncelle',
      initial: MealDraft(
        name: meal.name,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
      ),
    );
    if (draft == null) return;
    try {
      await ref.read(mealLogsProvider.notifier).updateMeal(meal.copyWith(
            name: draft.name,
            calories: draft.calories,
            protein: draft.protein,
            carbs: draft.carbs,
            fat: draft.fat,
          ));
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Öğün güncellenemedi.');
      }
    }
  }

  Future<void> _deleteMeal(
      BuildContext context, WidgetRef ref, MealLog meal) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(mealLogsProvider.notifier);
    try {
      await notifier.deleteMeal(meal.id);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${meal.name} silindi'),
          action: SnackBarAction(
            label: 'Geri al',
            textColor: AppColors.secondary,
            onPressed: () => notifier
                .addMeal(
                  name: meal.name,
                  calories: meal.calories,
                  insight: meal.insight,
                  protein: meal.protein,
                  carbs: meal.carbs,
                  fat: meal.fat,
                )
                .catchError((_) {}),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Öğün silinemedi. Veritabanında silme izni (supabase_phase3.sql) gerekli olabilir.',
            style: TextStyle(color: AppColors.danger)),
      ));
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: TextStyle(color: AppColors.danger)),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsState = ref.watch(mealLogsProvider);
    final fullName =
        (ref.watch(userProfileProvider).valueOrNull?['full_name'] as String?)
                ?.trim() ??
            '';
    final userEmail = SupabaseService.getCurrentUser()?.email ?? '';
    final userName = fullName.isNotEmpty
        ? fullName.split(' ').first
        : (userEmail.contains('@') ? userEmail.split('@').first : userEmail);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(userProfileProvider);
        ref.invalidate(coachContentProvider);
        ref.invalidate(connectionsProvider);
        await ref.read(mealLogsProvider.notifier).loadMeals();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kalori Matik',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                if (userName.isNotEmpty)
                  Text(
                    '${_greeting()}, $userName 👋',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Geçmiş',
                icon: Icon(Icons.history_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => context.push('/history'),
              ),
            ],
          ),

          // ── Dairesel Gösterge ────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: CalorieCircularIndicator(),
            ),
          ),

          // ── Makro ve Su ─────────────────────────────────────────────────
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(child: MacroProgressCard()),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(child: WaterCard()),
          ),

          // ── Kilo Verme Hedefi + Koç kartı ──────────────────────────────
          const SliverToBoxAdapter(child: _WeightGoalCard()),
          const SliverToBoxAdapter(child: CoachSummaryCard()),

          // ── Bugünkü Öğünler Başlığı ───────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BUGÜNKÜ ÖĞÜNLER',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    '${mealsState.meals.length} öğün',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          if (mealsState.meals.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Düzenlemek için dokun, silmek için sola kaydır',
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Öğün Listesi ────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            sliver: mealsState.isLoading && mealsState.meals.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2),
                      ),
                    ),
                  )
                : mealsState.error != null && mealsState.meals.isEmpty
                    ? SliverToBoxAdapter(
                        child: _ErrorState(
                          message: mealsState.error!,
                          onRetry: () =>
                              ref.read(mealLogsProvider.notifier).loadMeals(),
                        ),
                      )
                    : mealsState.meals.isEmpty
                        ? const SliverToBoxAdapter(child: _EmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final meal = mealsState.meals[index];
                                final isTemp = meal.id.startsWith('temp-');
                                return MealListItem(
                                  key: ValueKey(meal.id),
                                  meal: meal,
                                  onTap: isTemp
                                      ? null
                                      : () => _editMeal(context, ref, meal),
                                  onDelete: isTemp
                                      ? null
                                      : () => _deleteMeal(context, ref, meal),
                                );
                              },
                              childCount: mealsState.meals.length,
                            ),
                          ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }
}

class _WeightGoalCard extends ConsumerWidget {
  const _WeightGoalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile == null || profile['goal'] != 'lose') {
      return const SizedBox.shrink();
    }
    final targetKg = (profile['target_weight_loss'] as num?)?.toDouble();
    final targetDays = (profile['target_days'] as num?)?.toInt();
    if (targetKg == null || targetDays == null) return const SizedBox.shrink();
    final tdee = (profile['daily_tdee'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(Icons.trending_down, color: AppColors.textPrimary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hedef: −${targetKg.toStringAsFixed(1)} kg / $targetDays gün',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Günlük limit: $tdee kcal',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.no_food_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz öğün eklenmedi',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'İlk öğününüzü eklemek için\naşağıdaki kamera butonuna basın',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off, color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}
