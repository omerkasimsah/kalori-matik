import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../models/meal_log.dart';

// Günlük kalori hedefi limiti. Profil Supabase'den çekildiğinde güncellenebilir bir state provider.
final dailyBudgetProvider = StateProvider<int>((ref) => 2000);

// Kullanıcı Profil Verisi (Rol Tabanlı Erişim Kontrolü - RBAC ve UI tasarımı mantığı için)
// Bu provider uygulamada danışan, koç veya diyetisyen ayrımlarını sağlamak için asenkron izlenir.
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return await SupabaseService.getProfile();
});

// Öğün Listesi İçin Asenkron Durum (State) Modeli
class MealLogState {
  final List<MealLog> meals;
  final bool isLoading;
  MealLogState({required this.meals, required this.isLoading});
}

// O güne ait kullanıcı tarafından girilen öğünlerin listesini bellekte (state içerisinde) tutan Provider
final mealLogsProvider =
    StateNotifierProvider<MealLogNotifier, MealLogState>((ref) {
  return MealLogNotifier(ref);
});

// Toplam harcanan kalori (Yenilen Besinler)
final caloriesConsumedProvider = Provider<int>((ref) {
  final state = ref.watch(mealLogsProvider);
  return state.meals.fold(0, (sum, meal) => sum + meal.calories);
});

// Spor ve Aktivite'den kazanılan 'Aktif Kaloriler' (Harcanabilir Limite Eklenir)
final activeCaloriesProvider = StateProvider<int>((ref) => 320); // Mock default

// Kalan kalori (Finansal Harcama Metaforu: TDEE Bütçesi + Edilen Aktiviteden Kazanılan Bakiye - Yenilen Toplam Miktar)
// Bu provider üç farklı veri kaynağını birleştirerek ana ekrandaki kullanılabilir sınırı hesaplar.
final remainingBudgetProvider = Provider<int>((ref) {
  final baseBudget = ref.watch(dailyBudgetProvider);
  final activeCalories = ref.watch(activeCaloriesProvider);
  final consumed = ref.watch(caloriesConsumedProvider);
  
  return (baseBudget + activeCalories) - consumed;
});

// Veri katmanı değişikliklerini yöneten ve kullanıcı arayüzünü (UI) render eden ana StateNotifier Sınıfı
class MealLogNotifier extends StateNotifier<MealLogState> {
  final Ref _ref;

  MealLogNotifier(this._ref)
      : super(MealLogState(meals: [], isLoading: false)) {
    _init();
  }

  Future<void> _init() async {
    await loadUserBudget();
    await loadMeals();
  }

  /// Supabase'den kullanıcının daily_tdee değerini getirir ve provider'ı günceller.
  Future<void> loadUserBudget() async {
    if (SupabaseService.getCurrentUser() == null) return;
    try {
      final tdee = await SupabaseService.getDailyTdee();
      if (tdee != null && tdee > 0) {
        _ref.read(dailyBudgetProvider.notifier).state = tdee;
      }
    } catch (e) {
      // Profil henüz yoksa varsayılan 2000 kalır
    }
  }

  Future<void> loadMeals() async {
    if (SupabaseService.getCurrentUser() == null) return;

    state = MealLogState(meals: state.meals, isLoading: true);
    try {
      final meals = await SupabaseService.getTodayMeals();
      state = MealLogState(meals: meals, isLoading: false);
    } catch (e) {
      state = MealLogState(meals: state.meals, isLoading: false);
    }
  }

  Future<void> addMeal({
    required String name,
    required int calories,
    String? insight,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    // Optimistic UI Algoritması (Kullanıcı Deneyimi İyileştirmesi)
    // Supabase arka plan çağrısını beklemeden yeni öğünü anında kullanıcı arayüzüne ekler
    final newMeal = MealLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      calories: calories,
      time:
          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      insight: insight,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    state = MealLogState(meals: [newMeal, ...state.meals], isLoading: state.isLoading);

    if (SupabaseService.getCurrentUser() != null) {
      try {
        await SupabaseService.addMealLog(
          name: name,
          calories: calories,
          insight: insight,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
        // Gerçek ID için yenile
        loadMeals();
      } catch (e) {
        // Sessiz hata – UI zaten güncellendi
      }
    }
  }
}
