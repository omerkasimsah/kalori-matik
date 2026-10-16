import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/calorie_calculator.dart';
import '../../activity/providers/activity_log_provider.dart';
import '../../activity/providers/pedometer_provider.dart';
import '../models/meal_log.dart';

// ── OTURUM ──────────────────────────────────────────────────────────────────

/// Supabase oturum olaylarını dinler (giriş, çıkış, token yenileme).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.client.auth.onAuthStateChange;
});

/// Giriş yapmış kullanıcının kimliği. Kullanıcı değiştiğinde (çıkış / başka
/// hesapla giriş) buna bağlı tüm provider'lar otomatik olarak sıfırlanır.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return SupabaseService.getCurrentUser()?.id;
});

// ── PROFİL ve HEDEFLER ──────────────────────────────────────────────────────

// Kullanıcı Profil Verisi (Rol Tabanlı Erişim Kontrolü - RBAC ve UI tasarımı mantığı için)
// Bu provider uygulamada danışan, koç veya diyetisyen ayrımlarını sağlamak için asenkron izlenir.
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return SupabaseService.getProfile();
});

/// Günlük kalori hedefi (profilden; yoksa 2000 kcal).
final dailyBudgetProvider = Provider<int>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  final tdee = (profile?['daily_tdee'] as num?)?.toInt();
  return (tdee != null && tdee > 0) ? tdee : 2000;
});

/// Kullanıcının kilosu (adım → kalori ve su hedefi hesapları için).
final userWeightProvider = Provider<double?>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return (profile?['weight'] as num?)?.toDouble();
});

/// Günlük makro hedefleri.
final macroTargetsProvider = Provider<MacroTargets>((ref) {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return CalorieCalculator.macroTargets(
    calories: ref.watch(dailyBudgetProvider),
    goal: (profile?['goal'] as String?) ?? 'maintain',
  );
});

// ── ÖĞÜNLER ─────────────────────────────────────────────────────────────────

// Öğün Listesi İçin Asenkron Durum (State) Modeli
class MealLogState {
  final List<MealLog> meals;
  final bool isLoading;
  final String? error;

  const MealLogState({
    required this.meals,
    this.isLoading = false,
    this.error,
  });

  MealLogState copyWith({
    List<MealLog>? meals,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MealLogState(
      meals: meals ?? this.meals,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// O güne ait kullanıcı tarafından girilen öğünlerin listesini bellekte (state içerisinde) tutan Provider
final mealLogsProvider =
    StateNotifierProvider<MealLogNotifier, MealLogState>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return MealLogNotifier(userId: userId);
});

// Toplam alınan kalori (Yenilen Besinler)
final caloriesConsumedProvider = Provider<int>((ref) {
  final state = ref.watch(mealLogsProvider);
  return state.meals.fold(0, (sum, meal) => sum + meal.calories);
});

/// Bugün alınan toplam makrolar (gram).
final macrosConsumedProvider =
    Provider<({double protein, double carbs, double fat})>((ref) {
  final meals = ref.watch(mealLogsProvider).meals;
  double p = 0, c = 0, f = 0;
  for (final m in meals) {
    p += m.protein ?? 0;
    c += m.carbs ?? 0;
    f += m.fat ?? 0;
  }
  return (protein: p, carbs: c, fat: f);
});

// Adımlardan ve kaydedilen spor/antrenmanlardan gelen 'Aktif Kaloriler'
// (harcanabilir limite eklenir). Yürüyüş kaydı ile adımların çift
// sayılmaması için adımlar yalnızca kayıtsız hareketi temsil eder.
final stepCaloriesProvider = Provider<int>((ref) {
  final steps = ref.watch(pedometerProvider.select((s) => s.steps));
  final weight = ref.watch(userWeightProvider) ?? 70;
  return CalorieCalculator.stepsToCalories(steps, weightKg: weight);
});

final activeCaloriesProvider = Provider<int>((ref) {
  return ref.watch(stepCaloriesProvider) +
      ref.watch(loggedActivityCaloriesProvider);
});

// Kalan kalori (Bütçe + Aktiviteden Kazanılan - Yenilen)
final remainingBudgetProvider = Provider<int>((ref) {
  final baseBudget = ref.watch(dailyBudgetProvider);
  final activeCalories = ref.watch(activeCaloriesProvider);
  final consumed = ref.watch(caloriesConsumedProvider);
  return (baseBudget + activeCalories) - consumed;
});

// Veri katmanı değişikliklerini yöneten ana StateNotifier Sınıfı
class MealLogNotifier extends StateNotifier<MealLogState> {
  final String? userId;
  DateTime _loadedDay = _today();

  MealLogNotifier({required this.userId})
      : super(const MealLogState(meals: [])) {
    if (userId != null) loadMeals();
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Gün değiştiyse (uygulama gece yarısından sonra öne alındığında) listeyi yeniler.
  Future<void> refreshIfNewDay() async {
    if (_loadedDay != _today()) await loadMeals();
  }

  Future<void> loadMeals() async {
    if (userId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final meals = await SupabaseService.getTodayMeals();
      _loadedDay = _today();
      if (mounted) state = MealLogState(meals: meals);
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
            isLoading: false, error: 'Öğünler yüklenemedi. Bağlantınızı kontrol edin.');
      }
    }
  }

  /// Öğünü ekler. Arayüz anında güncellenir (optimistic UI); kayıt başarısız
  /// olursa geri alınır ve hata fırlatılır.
  Future<void> addMeal({
    required String name,
    required int calories,
    String? insight,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    final tempMeal = MealLog(
      id: 'temp-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      calories: calories,
      createdAt: DateTime.now(),
      insight: insight,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    state = state.copyWith(meals: [tempMeal, ...state.meals]);

    try {
      final saved = await SupabaseService.addMealLog(
        name: name,
        calories: calories,
        insight: insight,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
      if (!mounted) return;
      state = state.copyWith(
        meals: [
          for (final m in state.meals) m.id == tempMeal.id ? saved : m,
        ],
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
            meals: state.meals.where((m) => m.id != tempMeal.id).toList());
      }
      rethrow;
    }
  }

  /// Öğünü günceller; başarısız olursa eski hali geri yüklenir.
  Future<void> updateMeal(MealLog updated) async {
    final previous = state.meals;
    state = state.copyWith(
      meals: [for (final m in previous) m.id == updated.id ? updated : m],
    );
    try {
      await SupabaseService.updateMealLog(updated);
    } catch (e) {
      if (mounted) state = state.copyWith(meals: previous);
      rethrow;
    }
  }

  /// Öğünü siler; başarısız olursa geri yüklenir.
  Future<void> deleteMeal(String id) async {
    final previous = state.meals;
    state = state.copyWith(meals: previous.where((m) => m.id != id).toList());
    try {
      await SupabaseService.deleteMealLog(id);
    } catch (e) {
      if (mounted) state = state.copyWith(meals: previous);
      rethrow;
    }
  }
}
