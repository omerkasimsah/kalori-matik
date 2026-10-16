import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/models/meal_log.dart';
import '../config/app_config.dart';
import 'demo_backend.dart';

class SupabaseService {
  // Supabase istemcisinin tekil (singleton) örneğine güvenli erişim noktası
  static final SupabaseClient client = Supabase.instance.client;

  /// Demo modunda tüm veriler bellekten gelir (bkz. DemoBackend).
  static bool get isDemo => AppConfig.isDemo;

  /// Geçerli bir oturum var mı?
  static bool get isLoggedIn =>
      isDemo ? DemoBackend.signedIn : client.auth.currentSession != null;

  // ── KİMLİK DOĞRULAMA (AUTH) ────────────────────────────────────────────────

  static Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email.trim(), password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    if (isDemo) {
      DemoBackend.signIn();
      return AuthResponse(user: DemoBackend.user);
    }
    return await client.auth
        .signInWithPassword(email: email.trim(), password: password);
  }

  static Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  /// Supabase kimlik doğrulama hatalarını anlaşılır Türkçe mesaja çevirir.
  static String authErrorMessage(Object error) {
    final msg = (error is AuthException ? error.message : error.toString())
        .toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (msg.contains('email not confirmed')) {
      return 'E-posta adresinizi henüz doğrulamadınız. Gelen kutunuzu kontrol edin.';
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'Bu e-posta ile zaten bir hesap var. Giriş yapmayı deneyin.';
    }
    if (msg.contains('password') && msg.contains('at least')) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.';
    }
    if (msg.contains('invalid') && msg.contains('email')) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    if (msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception')) {
      return 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
    }
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  static Future<void> signOut() async {
    if (isDemo) return DemoBackend.signOut();
    await client.auth.signOut();
  }

  /// Hesabı ve tüm verileri kalıcı olarak siler (Google Play zorunluluğu).
  static Future<void> deleteMyAccount() async {
    if (isDemo) return DemoBackend.signOut();
    await client.rpc('delete_my_account');
    await client.auth.signOut();
  }

  // Senkron olarak o an sisteme giriş yapmış kullanıcı bilgisini döner
  static User? getCurrentUser() {
    if (isDemo) return DemoBackend.signedIn ? DemoBackend.user : null;
    return client.auth.currentUser;
  }

  // ── KULLANICI PROFİLİ YÖNETİMİ ───────────────────────────────────────────

  // Verilen profil verisini Supabase 'profiles' tablosuna kaydeder veya günceller (Upsert tekniği)
  static Future<void> saveProfile(Map<String, dynamic> profileData) async {
    if (isDemo) return DemoBackend.saveProfile(profileData);
    final user = getCurrentUser();
    if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');

    // Veri yapısına, güvenliği sağlamak için auth kullanıcısının ID'si gömülür
    profileData['id'] = user.id;
    try {
      await client.from('profiles').upsert(profileData);
    } on PostgrestException catch (e) {
      // phase4 SQL henüz çalıştırılmadıysa 'full_name' sütunu yoktur.
      if (profileData.containsKey('full_name') &&
          e.message.contains('full_name')) {
        final copy = Map<String, dynamic>.of(profileData)..remove('full_name');
        await client.from('profiles').upsert(copy);
      } else {
        rethrow;
      }
    }
  }

  static Future<Map<String, dynamic>?> getProfile() async {
    if (isDemo) return DemoBackend.profile;
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
    if (isDemo) throw Exception('Demo modunda danışan eklenemez.');
    final user = getCurrentUser();
    if (user == null) throw Exception('Profesyonel girişi yapılmamış.');

    // 1. Danışanı KaloriID ile bul.
    // RLS bağlı olmayan profilleri gizlediği için önce SECURITY DEFINER
    // fonksiyonu (supabase/migrations) denenir; yoksa doğrudan sorguya düşülür.
    final code = kaloriId.trim().toUpperCase();
    Map<String, dynamic>? clientData;
    try {
      final res = await client
          .rpc('find_client_by_kalori_id', params: {'p_kalori_id': code});
      if (res is List && res.isNotEmpty) {
        clientData = Map<String, dynamic>.from(res.first as Map);
      }
    } catch (_) {
      clientData = await client
          .from('profiles')
          .select('id, role')
          .eq('kalori_id', code)
          .maybeSingle();
    }

    if (clientData == null) {
      throw Exception('Bu KaloriID\'ye sahip bir kullanıcı bulunamadı.');
    }

    if (clientData['role'] != 'client') {
      throw Exception('Bu kod bir danışana ait değil.');
    }

    if (clientData['id'] == user.id) {
      throw Exception('Kendinizi danışan olarak ekleyemezsiniz.');
    }

    // 2. Bağlantı oluştur (zaten varsa uyar)
    final existing = await client
        .from('connections')
        .select('id, status')
        .eq('professional_id', user.id)
        .eq('client_id', clientData['id'])
        .maybeSingle();
    if (existing != null) {
      throw Exception(existing['status'] == 'active'
          ? 'Bu danışan zaten listenizde.'
          : 'Bu danışana davet zaten gönderildi, onayını bekliyor.');
    }
    await client.from('connections').insert({
      'professional_id': user.id,
      'client_id': clientData['id'],
      'status': 'pending', // danışan onaylayınca 'active' olur
    });
  }

  // Sisteme giriş yapmış profesyonelin danışanlarının listesini getirir
  static Future<List<Map<String, dynamic>>> getMyClients() async {
    if (isDemo) return DemoBackend.clientConnections;
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
        .eq('professional_id', user.id)
        .eq('status', 'active');

    return List<Map<String, dynamic>>.from(response);
  }

  // Danışanın profilini güncelle (koç/diyetisyen tarafından)
  static Future<void> updateClientProfile(String clientId, Map<String, dynamic> updates) async {
    if (isDemo) return;
    await client.from('profiles').update(updates).eq('id', clientId);
  }

  // ── ANTRENMAN PLANI YÖNETİMİ ─────────────────────────────────────────────

  /// Koçun belirli bir danışan için tüm antrenman planlarını getirir
  static Future<List<Map<String, dynamic>>> getWorkoutPlans(String clientId) async {
    if (isDemo) return DemoBackend.workoutPlans;
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
    if (isDemo) return {'id': 'demo', 'title': title, 'workout_exercises': []};
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
    if (isDemo) return;
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
    if (isDemo) return;
    await client.from('workout_exercises').delete().eq('id', exerciseId);
  }

  /// Antrenman planını siler
  static Future<void> deleteWorkoutPlan(String planId) async {
    if (isDemo) return;
    await client.from('workout_plans').delete().eq('id', planId);
  }

  // ── BESLENME PLANI YÖNETİMİ ──────────────────────────────────────────────

  /// Danışanın beslenme planını getirir
  static Future<List<Map<String, dynamic>>> getNutritionPlan(String clientId) async {
    if (isDemo) return DemoBackend.nutritionPlan;
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
    if (isDemo) return;
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
    if (isDemo) return;
    await client.from('nutrition_plans').delete().eq('id', itemId);
  }

  // ── KOÇ NOTLARI ──────────────────────────────────────────────────────────

  /// Danışan için koç notlarını getirir
  static Future<List<Map<String, dynamic>>> getCoachNotes(String clientId) async {
    if (isDemo) return DemoBackend.coachNotes;
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
    if (isDemo) return;
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
    if (isDemo) return;
    await client.from('coach_notes').delete().eq('id', noteId);
  }

  // ── MEAL LOGS ─────────────────────────────────────────────────────────────

  /// Yeni öğün kaydı ekler ve veritabanının oluşturduğu kaydı döndürür.
  static Future<MealLog> addMealLog({
    required String name,
    required int calories,
    String? insight,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    if (isDemo) {
      return DemoBackend.addMeal(MealLog(
        id: '',
        name: name,
        calories: calories,
        createdAt: DateTime.now(),
        insight: insight,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ));
    }
    final user = getCurrentUser();
    if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');

    final row = await client
        .from('meal_logs')
        .insert({
          'user_id': user.id,
          'name': name,
          'calories': calories,
          'insight': insight,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        })
        .select()
        .single();
    return MealLog.fromMap(row);
  }

  /// Öğün kaydını günceller. RLS izin vermezse hata fırlatır.
  static Future<void> updateMealLog(MealLog meal) async {
    if (isDemo) return DemoBackend.updateMeal(meal);
    final rows = await client
        .from('meal_logs')
        .update({
          'name': meal.name,
          'calories': meal.calories,
          'protein': meal.protein,
          'carbs': meal.carbs,
          'fat': meal.fat,
        })
        .eq('id', meal.id)
        .select('id');
    if (rows.isEmpty) {
      throw Exception('Öğün güncellenemedi (yetki yok).');
    }
  }

  /// Öğün kaydını siler. RLS izin vermezse hata fırlatır.
  static Future<void> deleteMealLog(String id) async {
    if (isDemo) return DemoBackend.deleteMeal(id);
    final rows =
        await client.from('meal_logs').delete().eq('id', id).select('id');
    if (rows.isEmpty) {
      throw Exception('Öğün silinemedi (yetki yok).');
    }
  }

  static String _startOfDayUtc([DateTime? day]) {
    final d = day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
  }

  static Future<List<MealLog>> getTodayMeals() async {
    final user = getCurrentUser();
    if (user == null) return [];
    return getMealsForUser(user.id);
  }

  // Profesyonel kullanıcının belirli bir danışanının bugünkü öğünlerini getirir
  static Future<List<MealLog>> getClientTodayMeals(String clientId) =>
      getMealsForUser(clientId);

  static Future<List<MealLog>> getMealsForUser(String userId) async {
    if (isDemo) {
      final n = DateTime.now();
      return DemoBackend.mealsSince(userId, DateTime(n.year, n.month, n.day))
          .map(DemoBackend.applyFeedback)
          .toList();
    }
    final response = await client
        .from('meal_logs')
        .select()
        .eq('user_id', userId)
        .gte('created_at', _startOfDayUtc())
        .order('created_at', ascending: false);
    return _parseMeals(response);
  }

  /// Son [days] günlük tüm öğünleri getirir (bugün dahil).
  static Future<List<MealLog>> getAllMeals({int days = 30}) async {
    if (isDemo) {
      final n = DateTime.now();
      return DemoBackend.mealsSince(
          DemoBackend.userId, DateTime(n.year, n.month, n.day - (days - 1)));
    }
    final user = getCurrentUser();
    if (user == null) return [];

    final since =
        _startOfDayUtc(DateTime.now().subtract(Duration(days: days - 1)));

    final response = await client
        .from('meal_logs')
        .select()
        .eq('user_id', user.id)
        .gte('created_at', since)
        .order('created_at', ascending: false);

    return _parseMeals(response);
  }

  /// Son [days] günün günlük kalori ve makro toplamlarını (eskiden yeniye) döndürür.
  static Future<List<DailyTotal>> getDailyTotals({int days = 7}) async {
    final meals = await getAllMeals(days: days);
    return DailyTotal.group(meals, days: days);
  }

  static List<MealLog> _parseMeals(List<dynamic> response) {
    return response
        .map((e) => MealLog.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── KOÇ TAKİBİ ───────────────────────────────────────────────────────────

  /// Bir kullanıcının son [days] günlük öğünleri (koç danışanını izlerken).
  static Future<List<MealLog>> getMealsForUserSince(String userId,
      {int days = 7}) async {
    final n = DateTime.now();
    final since = DateTime(n.year, n.month, n.day - (days - 1));
    if (isDemo) {
      return DemoBackend.mealsSince(userId, since)
          .map(DemoBackend.applyFeedback)
          .toList();
    }
    final response = await client
        .from('meal_logs')
        .select()
        .eq('user_id', userId)
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return _parseMeals(response);
  }

  /// Birden çok danışanın son [days] günlük öğünlerini tek sorguda getirir.
  static Future<Map<String, List<MealLog>>> getClientsMeals(
      List<String> userIds,
      {int days = 7}) async {
    final result = {for (final id in userIds) id: <MealLog>[]};
    if (userIds.isEmpty) return result;
    final n = DateTime.now();
    final since = DateTime(n.year, n.month, n.day - (days - 1));
    if (isDemo) {
      for (final id in userIds) {
        result[id] = DemoBackend.mealsSince(id, since);
      }
      return result;
    }
    final response = await client
        .from('meal_logs')
        .select()
        .inFilter('user_id', userIds)
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    for (final row in response) {
      final m = Map<String, dynamic>.from(row as Map);
      result[m['user_id'].toString()]?.add(MealLog.fromMap(m));
    }
    return result;
  }

  /// Koçun bir öğüne yorum bırakması (boş metin yorumu siler).
  static Future<void> setMealFeedback(String mealId, String comment) async {
    if (isDemo) return DemoBackend.setMealFeedback(mealId, comment);
    await client.rpc('set_meal_feedback',
        params: {'p_meal_id': mealId, 'p_comment': comment});
  }

  /// Koç–danışan bağlantısını sonlandırır.
  static Future<void> removeConnection(String connectionId) async {
    if (isDemo) return DemoBackend.respond(connectionId, false);
    await client.from('connections').delete().eq('id', connectionId);
  }

  // ── KİLO TAKİBİ ──────────────────────────────────────────────────────────

  /// Kilo kayıtları (eskiden yeniye). [userId] verilmezse giriş yapan kullanıcı.
  static Future<List<WeightEntry>> getWeightLogs({String? userId,
      int days = 120}) async {
    final uid = userId ?? getCurrentUser()?.id;
    if (uid == null) return [];
    final List<dynamic> rows;
    if (isDemo) {
      rows = DemoBackend.weightsFor(uid);
    } else {
      rows = await client
          .from('weight_logs')
          .select()
          .eq('user_id', uid)
          .gte(
              'created_at',
              DateTime.now()
                  .subtract(Duration(days: days))
                  .toUtc()
                  .toIso8601String())
          .order('created_at', ascending: true);
    }
    return rows
        .map((e) => WeightEntry.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Yeni kilo kaydı ekler ve profildeki güncel kiloyu günceller.
  static Future<void> addWeightLog(double weight) async {
    if (isDemo) return DemoBackend.addWeight(weight);
    final user = getCurrentUser();
    if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');
    await client
        .from('weight_logs')
        .insert({'user_id': user.id, 'weight': weight});
    await client.from('profiles').update({'weight': weight}).eq('id', user.id);
  }

  /// Danışanın koç/diyetisyen bağlantıları (bekleyen davetler dahil).
  static Future<List<CoachConnection>> getMyConnections() async {
    if (isDemo) return DemoBackend.connections;
    if (getCurrentUser() == null) return [];
    final rows = await client.rpc('my_connections');
    return (rows as List)
        .map((e) => CoachConnection.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Gelen daveti kabul eder veya reddeder.
  static Future<void> respondToConnection(String id, {required bool accept}) async {
    if (isDemo) return DemoBackend.respond(id, accept);
    await client.rpc('respond_to_connection',
        params: {'p_id': id, 'p_accept': accept});
  }

  // ── KOÇ İÇERİKLERİ (DANIŞAN TARAFI) ─────────────────────────────────────

  /// Giriş yapmış danışana atanmış beslenme planı.
  static Future<List<Map<String, dynamic>>> getMyNutritionPlan() async {
    if (isDemo) return DemoBackend.nutritionPlan;
    final user = getCurrentUser();
    if (user == null) return [];
    final response = await client
        .from('nutrition_plans')
        .select()
        .eq('client_id', user.id)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Giriş yapmış danışana yazılan koç notları.
  static Future<List<Map<String, dynamic>>> getMyCoachNotes() async {
    if (isDemo) return DemoBackend.coachNotes;
    final user = getCurrentUser();
    if (user == null) return [];
    final response = await client
        .from('coach_notes')
        .select()
        .eq('client_id', user.id)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Giriş yapmış danışana atanmış aktif antrenman planları.
  static Future<List<Map<String, dynamic>>> getMyWorkoutPlans() async {
    if (isDemo) return DemoBackend.workoutPlans;
    final user = getCurrentUser();
    if (user == null) return [];
    final response = await client
        .from('workout_plans')
        .select('*, workout_exercises (*)')
        .eq('client_id', user.id)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}

/// Bir güne ait toplam kalori ve makrolar.
class DailyTotal {
  final DateTime date;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final int mealCount;

  const DailyTotal({
    required this.date,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.mealCount = 0,
  });

  DailyTotal add(MealLog m) => DailyTotal(
        date: date,
        calories: calories + m.calories,
        protein: protein + (m.protein ?? 0),
        carbs: carbs + (m.carbs ?? 0),
        fat: fat + (m.fat ?? 0),
        mealCount: mealCount + 1,
      );

  /// Öğünleri son [days] güne (bugün dahil, eskiden yeniye) dağıtır.
  /// Hiç öğün olmayan günler de sıfır değerle listede yer alır.
  static List<DailyTotal> group(List<MealLog> meals,
      {int days = 7, DateTime? now}) {
    final today = now ?? DateTime.now();
    final byDay = <DateTime, DailyTotal>{};
    for (int i = days - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      byDay[d] = DailyTotal(date: d);
    }
    for (final m in meals) {
      final t = byDay[m.day];
      if (t != null) byDay[m.day] = t.add(m);
    }
    return byDay.values.toList();
  }
}

/// Tek bir kilo ölçümü.
class WeightEntry {
  final double weight;
  final DateTime date;

  const WeightEntry({required this.weight, required this.date});

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
        weight: (map['weight'] as num).toDouble(),
        date: DateTime.parse(map['created_at'].toString()).toLocal(),
      );
}

/// Danışanın gördüğü koç/diyetisyen bağlantısı.
class CoachConnection {
  final String id;
  final bool isActive;
  final String? name;
  final String? role;

  const CoachConnection({
    required this.id,
    required this.isActive,
    this.name,
    this.role,
  });

  factory CoachConnection.fromMap(Map<String, dynamic> m) => CoachConnection(
        id: m['id'].toString(),
        isActive: m['status'] == 'active',
        name: m['professional_name'] as String?,
        role: m['professional_role'] as String?,
      );

  String get roleLabel => role == 'dietitian' ? 'Diyetisyen' : 'Koç';

  /// Ad yoksa rolü gösterir.
  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : roleLabel;
}
