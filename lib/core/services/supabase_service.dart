import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/home/models/meal_log.dart';

class SupabaseService {
  // Supabase istemcisinin tekil (singleton) örneğine güvenli erişim noktası
  static final SupabaseClient client = Supabase.instance.client;

  // ── KİMLİK DOĞRULAMA (AUTH) ────────────────────────────────────────────────

  static Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Senkron olarak o an sisteme giriş yapmış kullanıcı bilgisini döner
  static User? getCurrentUser() {
    return client.auth.currentUser;
  }

  // ── KULLANICI PROFİLİ YÖNETİMİ ───────────────────────────────────────────

  // Verilen profil verisini Supabase 'profiles' tablosuna kaydeder veya günceller (Upsert tekniği)
  static Future<void> saveProfile(Map<String, dynamic> profileData) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');

    // Veri yapısına, güvenliği sağlamak için auth kullanıcısının ID'si gömülür
    profileData['id'] = user.id;
    await client.from('profiles').upsert(profileData);
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    final user = getCurrentUser();
    if (user == null) return null;
    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return data;
  }

  /// Kullanıcının günlük hedef TDEE (Total Daily Energy Expenditure) kalori miktarını döndürür.
  static Future<int?> getDailyTdee() async {
    final profile = await getProfile();
    if (profile == null) return null;
    final tdee = profile['daily_tdee'];
    if (tdee == null) return null;

    if (tdee is int) return tdee;
    if (tdee is double) return tdee.round();
    return int.tryParse(tdee.toString());
  }

  // ── PROFESYONEL YÖNETİMİ (KOÇ / DİYETİSYEN) ──────────────────────────────

  static Future<void> addClientByKaloriId(String kaloriId) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('Profesyonel girişi yapılmamış.');

    // 1. Danışanı KaloriID ile bul
    final clientData = await client
        .from('profiles')
        .select('id, role')
        .eq('kalori_id', kaloriId)
        .maybeSingle();

    if (clientData == null) {
      throw Exception('Bu KaloriID\'ye sahip bir kullanıcı bulunamadı.');
    }

    if (clientData['role'] != 'client') {
      throw Exception('Bu kod bir danışana ait değil.');
    }

    // 2. Bağlantı oluştur
    await client.from('connections').insert({
      'professional_id': user.id,
      'client_id': clientData['id'],
      'status': 'active',
    });
  }

  // Sisteme giriş yapmış profesyonelin danışanlarının listesini getirir
  static Future<List<Map<String, dynamic>>> getMyClients() async {
    final user = getCurrentUser();
    if (user == null) return [];

    final response = await client
        .from('connections')
        .select('''
          id,
          status,
          created_at,
          profiles!connections_client_id_fkey (*)
        ''')
        .eq('professional_id', user.id);

    return List<Map<String, dynamic>>.from(response);
  }

  // Danışanın profilini güncelle (koç/diyetisyen tarafından)
  static Future<void> updateClientProfile(String clientId, Map<String, dynamic> updates) async {
    await client.from('profiles').update(updates).eq('id', clientId);
  }

  // ── ANTRENMAN PLANI YÖNETİMİ ─────────────────────────────────────────────

  /// Koçun belirli bir danışan için tüm antrenman planlarını getirir
  static Future<List<Map<String, dynamic>>> getWorkoutPlans(String clientId) async {
    final user = getCurrentUser();
    if (user == null) return [];

    final response = await client
        .from('workout_plans')
        .select('''
          *,
          workout_exercises (*)
        ''')
        .eq('coach_id', user.id)
        .eq('client_id', clientId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Yeni antrenman planı oluşturur
  static Future<Map<String, dynamic>> createWorkoutPlan({
    required String clientId,
    required String title,
    String? description,
    String? weekDay,
  }) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('Giriş yapılmamış.');

    final result = await client.from('workout_plans').insert({
      'coach_id': user.id,
      'client_id': clientId,
      'title': title,
      'description': description,
      'week_day': weekDay,
    }).select().single();

    return result;
  }

  /// Plana egzersiz ekler
  static Future<void> addExerciseToPlan({
    required String planId,
    required String name,
    required String category,
    int sets = 3,
    int reps = 12,
    int? durationSec,
    int restSec = 60,
    String? notes,
    int orderIndex = 0,
  }) async {
    await client.from('workout_exercises').insert({
      'plan_id': planId,
      'name': name,
      'category': category,
      'sets': sets,
      'reps': reps,
      'duration_sec': durationSec,
      'rest_sec': restSec,
      'notes': notes,
      'order_index': orderIndex,
    });
  }

  /// Egzersiz siler
  static Future<void> deleteExercise(String exerciseId) async {
    await client.from('workout_exercises').delete().eq('id', exerciseId);
  }

  /// Antrenman planını siler
  static Future<void> deleteWorkoutPlan(String planId) async {
    await client.from('workout_plans').delete().eq('id', planId);
  }

  // ── BESLENME PLANI YÖNETİMİ ──────────────────────────────────────────────

  /// Danışanın beslenme planını getirir
  static Future<List<Map<String, dynamic>>> getNutritionPlan(String clientId) async {
    final user = getCurrentUser();
    if (user == null) return [];

    final response = await client
        .from('nutrition_plans')
        .select()
        .eq('coach_id', user.id)
        .eq('client_id', clientId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Beslenme planına öğün ekler
  static Future<void> addNutritionPlanItem({
    required String clientId,
    required String mealTime,
    required String mealName,
    int? targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    String? notes,
  }) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('Giriş yapılmamış.');

    await client.from('nutrition_plans').insert({
      'coach_id': user.id,
      'client_id': clientId,
      'meal_time': mealTime,
      'meal_name': mealName,
      'target_calories': targetCalories,
      'target_protein': targetProtein,
      'target_carbs': targetCarbs,
      'target_fat': targetFat,
      'notes': notes,
    });
  }

  /// Beslenme planı öğünü siler
  static Future<void> deleteNutritionPlanItem(String itemId) async {
    await client.from('nutrition_plans').delete().eq('id', itemId);
  }

  // ── KOÇ NOTLARI ──────────────────────────────────────────────────────────

  /// Danışan için koç notlarını getirir
  static Future<List<Map<String, dynamic>>> getCoachNotes(String clientId) async {
    final user = getCurrentUser();
    if (user == null) return [];

    final response = await client
        .from('coach_notes')
        .select()
        .eq('coach_id', user.id)
        .eq('client_id', clientId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Yeni koç notu ekler
  static Future<void> addCoachNote({
    required String clientId,
    required String note,
    String category = 'genel',
  }) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('Giriş yapılmamış.');

    await client.from('coach_notes').insert({
      'coach_id': user.id,
      'client_id': clientId,
      'note': note,
      'category': category,
    });
  }

  /// Koç notunu siler
  static Future<void> deleteCoachNote(String noteId) async {
    await client.from('coach_notes').delete().eq('id', noteId);
  }

  // ── MEAL LOGS ─────────────────────────────────────────────────────────────

  static Future<void> addMealLog({
    required String name,
    required int calories,
    String? insight,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    final user = getCurrentUser();
    if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');

    await client.from('meal_logs').insert({
      'user_id': user.id,
      'name': name,
      'calories': calories,
      'insight': insight,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    });
  }

  static Future<List<MealLog>> getTodayMeals() async {
    final user = getCurrentUser();
    if (user == null) return [];

    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

    final response = await client
        .from('meal_logs')
        .select()
        .eq('user_id', user.id)
        .gte('created_at', startOfDay)
        .order('created_at', ascending: false);

    return _parseMeals(response);
  }

  // Profesyonel kullanıcının belirli bir danışanının bugünkü öğünlerini getirir
  static Future<List<MealLog>> getClientTodayMeals(String clientId) async {
    final now = DateTime.now();
    final startOfDay =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

    final response = await client
        .from('meal_logs')
        .select()
        .eq('user_id', clientId)
        .gte('created_at', startOfDay)
        .order('created_at', ascending: false);

    return _parseMeals(response);
  }

  /// Son 30 günlük tüm öğünleri getirir
  static Future<List<MealLog>> getAllMeals({int days = 30}) async {
    final user = getCurrentUser();
    if (user == null) return [];

    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toUtc()
        .toIso8601String();

    final response = await client
        .from('meal_logs')
        .select()
        .eq('user_id', user.id)
        .gte('created_at', since)
        .order('created_at', ascending: false);

    return _parseMeals(response);
  }

  /// Son 7 günlük günlük kalori toplamlarını döndürür
  static Future<List<Map<String, dynamic>>> getWeeklyCalories() async {
    final user = getCurrentUser();
    if (user == null) return [];

    final since = DateTime.now()
        .subtract(const Duration(days: 6))
        .toUtc()
        .toIso8601String();

    final response = await client
        .from('meal_logs')
        .select('calories, created_at')
        .eq('user_id', user.id)
        .gte('created_at', since)
        .order('created_at', ascending: true);

    // Günlere göre grupla
    final Map<String, int> dailyTotals = {};
    for (final row in (response as List)) {
      final date = DateTime.parse(row['created_at']).toLocal();
      final key =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
      dailyTotals[key] = (dailyTotals[key] ?? 0) + (row['calories'] as int? ?? 0);
    }

    // Son 7 günü sırayla döndür
    final result = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime.now().subtract(Duration(days: i));
      final key =
          '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
      result.add({'date': key, 'calories': dailyTotals[key] ?? 0});
    }
    return result;
  }

  static List<MealLog> _parseMeals(List<dynamic> response) {
    return response.map((e) {
      return MealLog(
        id: e['id'].toString(),
        name: e['name'] ?? 'Bilinmeyen',
        calories: e['calories'] ?? 0,
        time: DateTime.parse(e['created_at'])
            .toLocal()
            .toString()
            .substring(11, 16),
        insight: e['insight'],
        protein: _toDouble(e['protein']),
        carbs: _toDouble(e['carbs']),
        fat: _toDouble(e['fat']),
      );
    }).toList();
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
