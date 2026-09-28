import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/calorie_provider.dart';
import '../widgets/calorie_circular_indicator.dart';
import '../widgets/daily_tasks_widget.dart';
import '../widgets/meal_list_item.dart';
import '../../../core/services/supabase_service.dart';
import '../../stats/screens/stats_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../activity/screens/activity_screen.dart';
import '../../tracking/screens/tracking_screen.dart'; // YENİ: Takip Sekmesi
import 'professional_dashboard.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Alt navigasyon barında aktif olan sekmenin indeks numarası
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    print('HomeScreen initState() called');
  }

  // Tüm sekmeler bellekte tutulur (IndexedStack)
  final List<Widget> _screens = const [
    _CalorieDashboard(), // Sekme 1: Kalori
    ActivityScreen(),    // Sekme 2: Antrenman (Hero)
    TrackingScreen(),    // Sekme 3: Takip (Profesyonel Görevler)
    ProfileScreen(),     // Sekme 4: Profil
  ];

  @override
  Widget build(BuildContext context) {
    print('HomeScreen build() called. _selectedIndex = $_selectedIndex');
    final profileAsync = ref.watch(userProfileProvider);

    // Koç/Diyetisyen rolü kontrolü — sadece data geldiğinde
    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        body: Center(child: Text('Profil yüklenemedi: $e')),
      ),
      data: (profile) {
        // Rol tabanlı yönlendirme — Koç veya Diyetisyen ise ayrı panel
        if (profile != null) {
          final role = profile['role'];
          if (role == 'coach' || role == 'dietitian') {
            return const ProfessionalDashboard();
          }
        }

        // ── Danışan / Normal Kullanıcı Arayüzü ───────────────────────────
        // NOT: Scaffold burada DAIMA oluşturulur.
        // setState() _selectedIndex'i değiştirdiğinde Scaffold rebuild edilir
        // ve IndexedStack doğru sekmeyi gösterir.
        return Scaffold(
          backgroundColor: AppColors.background,
          body: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
              onPressed: () => context.push('/add-meal'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.add_a_photo_outlined,
                  size: 26, color: Colors.white),
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: Colors.white,
            elevation: 8,
            surfaceTintColor: Colors.transparent,
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
                    onTap: () {
                      print('Aktivite clicked!');
                      setState(() => _selectedIndex = 1);
                    },
                  ),
                  const SizedBox(width: 56), // FAB boşluğu
                  _NavItem(
                    icon: Icons.checklist_rounded,
                    label: 'Takip',
                    isSelected: _selectedIndex == 2,
                    onTap: () {
                      print('Takip clicked!');
                      setState(() => _selectedIndex = 2);
                    },
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profil',
                    isSelected: _selectedIndex == 3,
                    onTap: () {
                      print('Profil clicked!');
                      setState(() => _selectedIndex = 3);
                    },
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ana Sayfa İçeriği (Dashboard) ─────────────────────────────────────────────

class _CalorieDashboard extends ConsumerWidget {
  const _CalorieDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsState = ref.watch(mealLogsProvider);
    final userEmail = SupabaseService.getCurrentUser()?.email ?? '';
    final userName = userEmail.contains('@')
        ? userEmail.split('@').first
        : userEmail;

    return CustomScrollView(
      slivers: [
        // ── App Bar ─────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 0,
          pinned: true,
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: null,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kalori Matik',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              if (userName.isNotEmpty)
                Text(
                  'Hoşgeldin, $userName 👋',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              icon:
                  const Icon(Icons.refresh, color: AppColors.textSecondary),
              onPressed: () =>
                  ref.read(mealLogsProvider.notifier).loadMeals(),
            ),
          ],
        ),

        // ── Dairesel Gösterge ────────────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: CalorieCircularIndicator(),
          ),
        ),

        // ── Kilo Verme Hedef Hızlı Kartı (Varsa Göster) ─────────────────
        // Kullanıcı profil ekranına gitmeden kilo hedefini kısa yoldan görebilir.
        SliverToBoxAdapter(
          child: ref.watch(userProfileProvider).when(
            data: (profile) {
              if (profile == null) return const SizedBox.shrink();
              if (profile['goal'] != 'lose') return const SizedBox.shrink();
              final targetKg = (profile['target_weight_loss'] as num?)?.toDouble();
              final targetDays = (profile['target_days'] as num?)?.toInt();
              if (targetKg == null || targetDays == null) return const SizedBox.shrink();
              final tdee = (profile['daily_tdee'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.coolGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.trending_down,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hedef: −${targetKg.toStringAsFixed(1)} kg / $targetDays gün',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Günlük limit: $tdee kcal',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
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
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        // ── Bugünkü Harcamalar Başlığı ───────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          sliver: SliverToBoxAdapter(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BUGÜNKÜ HARCAMALAR',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppColors.textSecondary,
                      ),
                ),
                Text(
                  '${mealsState.meals.length} öğün',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── Öğün Listesi ────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          sliver: mealsState.isLoading
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                  ),
                )
              : mealsState.meals.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            MealListItem(meal: mealsState.meals[index]),
                        childCount: mealsState.meals.length,
                      ),
                    ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
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
            child: const Icon(Icons.no_food_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Henüz öğün eklenmedi',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'İlk öğününüzü eklemek için\naşağıdaki kamera butonuna basın',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
