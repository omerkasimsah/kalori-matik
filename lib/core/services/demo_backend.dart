import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/home/models/meal_log.dart';
import 'supabase_service.dart' show CoachConnection;
import '../config/app_config.dart';

/// `--dart-define=DEMO_MODE=client|coach` ile çalışan, internet ve hesap
/// gerektirmeyen bellek içi arka uç. Arayüz geliştirme, görsel test ve
/// Play Store ekran görüntüleri için kullanılır.
class DemoBackend {
  static bool get isCoach => AppConfig.demoMode == 'coach';

  static final String userId =
      isCoach ? 'demo-coach-0000' : 'demo-client-0000';

  static final User user = User(
    id: userId,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: isCoach ? 'dyt.elif@ornek.com' : 'ahmet@ornek.com',
    createdAt: DateTime(2026, 1, 1).toIso8601String(),
  );

  static bool _signedIn = true;
  static bool get signedIn => _signedIn;
  static void signOut() => _signedIn = false;
  static void signIn() => _signedIn = true;

  // ── Profiller ─────────────────────────────────────────────────────────────

  static final Map<String, dynamic> _clientProfile = {
    'id': 'demo-client-0000',
    'full_name': 'Ahmet Yılmaz',
    'role': 'client',
    'kalori_id': 'K7M2XA',
    'age': 29,
    'gender': 'Erkek',
    'height': 178,
    'weight': 82.4,
    'activity_level': 1.55,
    'goal': 'lose',
    'daily_tdee': 2150,
    'target_weight_loss': 6,
    'target_days': 90,
  };

  static final Map<String, dynamic> _coachProfile = {
    'id': 'demo-coach-0000',
    'full_name': 'Dyt. Elif Kaya',
    'role': 'dietitian',
  };

  static Map<String, dynamic> get profile =>
      Map.of(isCoach ? _coachProfile : _clientProfile);

  static void saveProfile(Map<String, dynamic> data) {
    (isCoach ? _coachProfile : _clientProfile).addAll(data);
  }

  // ── Öğünler ──────────────────────────────────────────────────────────────

  static const _foods = [
    ('Menemen ve tam buğday ekmeği', 420, 18.0, 38.0, 21.0),
    ('Yulaf, muz ve fıstık ezmesi', 390, 13.0, 55.0, 13.0),
    ('Izgara tavuk ve bulgur pilavı', 610, 46.0, 62.0, 16.0),
    ('Mercimek çorbası', 210, 11.0, 30.0, 5.0),
    ('Ton balıklı salata', 340, 31.0, 14.0, 17.0),
    ('Yoğurt ve ceviz', 220, 12.0, 10.0, 15.0),
    ('Köfte, piyaz', 680, 38.0, 42.0, 38.0),
    ('Fırın somon ve sebze', 520, 39.0, 20.0, 30.0),
    ('Elma', 95, 0.5, 25.0, 0.3),
    ('Kuru fasulye ve pilav', 640, 24.0, 98.0, 14.0),
    ('Lahmacun ve ayran', 560, 24.0, 70.0, 19.0),
    ('Protein bar', 210, 20.0, 22.0, 7.0),
  ];

  static List<MealLog>? _clientMeals;

  /// Danışanın son 30 günlük öğünleri (bugün dahil).
  static List<MealLog> mealsFor(String uid) {
    if (uid == 'demo-client-0000' && _clientMeals != null) {
      return _clientMeals!;
    }
    final seed = uid.codeUnits.fold<int>(0, (a, b) => a + b);
    final rnd = Random(seed);
    final now = DateTime.now();
    final list = <MealLog>[];
    final lazy = _clients.indexWhere((c) => c['id'] == uid) == 3;
    for (var d = 0; d < 30; d++) {
      // Bir danışan son 3 gündür kayıt girmiyor (koç panelinde uyarı için)
      if (lazy && d < 3) continue;
      if (d > 0 && rnd.nextDouble() < 0.12) continue; // bazı günler boş
      final day = DateTime(now.year, now.month, now.day - d);
      final hours = d == 0 ? [8, 13] : [8, 13, 16, 20];
      for (final h in hours) {
        if (d == 0 && h > now.hour) continue;
        final f = _foods[rnd.nextInt(_foods.length)];
        list.add(MealLog(
          id: '$uid-$d-$h',
          name: f.$1,
          calories: f.$2,
          protein: f.$3,
          carbs: f.$4,
          fat: f.$5,
          createdAt: day.add(Duration(hours: h, minutes: rnd.nextInt(50))),
          insight: d == 0 && h == 8
              ? 'Güne proteinli başlamak tokluğu uzatır.'
              : null,
          coachComment: d == 0 && h == 13
              ? 'Porsiyon gayet iyi, bulgur yerine akşam salata da olur 👍'
              : null,
        ));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (uid == 'demo-client-0000') _clientMeals = list;
    return list;
  }

  static List<MealLog> mealsSince(String uid, DateTime since) =>
      mealsFor(uid).where((m) => !m.createdAt.isBefore(since)).toList();

  static MealLog addMeal(MealLog meal) {
    final saved = meal.copyWith(id: 'demo-${DateTime.now().microsecondsSinceEpoch}');
    mealsFor(userId).insert(0, saved);
    return saved;
  }

  static void updateMeal(MealLog meal) {
    final list = mealsFor(userId);
    final i = list.indexWhere((m) => m.id == meal.id);
    if (i >= 0) list[i] = meal;
  }

  static void deleteMeal(String id) =>
      mealsFor(userId).removeWhere((m) => m.id == id);

  // ── Kilo ─────────────────────────────────────────────────────────────────

  static final List<Map<String, dynamic>> _weights = () {
    final now = DateTime.now();
    const values = [86.1, 85.6, 85.4, 84.7, 84.3, 83.9, 83.2, 82.9, 82.4];
    return [
      for (var i = 0; i < values.length; i++)
        {
          'id': 'w$i',
          'weight': values[i],
          'created_at': now
              .subtract(Duration(days: (values.length - 1 - i) * 7))
              .toUtc()
              .toIso8601String(),
        }
    ];
  }();

  static List<Map<String, dynamic>> weightsFor(String uid) {
    if (uid == 'demo-client-0000') return List.of(_weights);
    final seed = uid.codeUnits.fold<int>(0, (a, b) => a + b);
    final rnd = Random(seed);
    final start = 70 + rnd.nextInt(25).toDouble();
    final now = DateTime.now();
    return [
      for (var i = 0; i < 8; i++)
        {
          'id': '$uid-w$i',
          'weight': double.parse(
              (start - i * (0.2 + rnd.nextDouble() * 0.5)).toStringAsFixed(1)),
          'created_at': now
              .subtract(Duration(days: (7 - i) * 7))
              .toUtc()
              .toIso8601String(),
        }
    ];
  }

  static void addWeight(double w) {
    _weights.add({
      'id': 'w${_weights.length}',
      'weight': w,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    _clientProfile['weight'] = w;
  }

  // ── Koç içerikleri ───────────────────────────────────────────────────────

  static final List<Map<String, dynamic>> nutritionPlan = [
    {
      'id': 'n1',
      'meal_time': 'Kahvaltı',
      'meal_name': '2 yumurta, 1 dilim peynir, bol yeşillik, 1 dilim tam buğday ekmeği',
      'target_calories': 450,
      'target_protein': 28,
      'target_carbs': 35,
      'target_fat': 20,
    },
    {
      'id': 'n2',
      'meal_time': 'Öğle',
      'meal_name': 'Izgara tavuk (150 g), bulgur pilavı (4 kaşık), salata',
      'target_calories': 600,
      'target_protein': 45,
      'notes': 'Salatayı zeytinyağı ile, limonlu.',
    },
    {
      'id': 'n3',
      'meal_time': 'Ara Öğün',
      'meal_name': '1 kase yoğurt + 3 ceviz',
      'target_calories': 220,
    },
    {
      'id': 'n4',
      'meal_time': 'Akşam',
      'meal_name': 'Sebze yemeği + yoğurt, ekmeksiz',
      'target_calories': 500,
    },
  ];

  static final List<Map<String, dynamic>> coachNotes = [
    {
      'id': 'c1',
      'note':
          'Bu hafta su tüketimin çok iyi! Akşam atıştırmalarını azaltırsak 0.5 kg daha veririz.',
      'category': 'motivasyon',
      'created_at': DateTime.now()
          .subtract(const Duration(days: 1))
          .toUtc()
          .toIso8601String(),
    },
    {
      'id': 'c2',
      'note': 'Haftada 3 gün 30 dk tempolu yürüyüş ekliyoruz.',
      'category': 'antrenman',
      'created_at': DateTime.now()
          .subtract(const Duration(days: 6))
          .toUtc()
          .toIso8601String(),
    },
  ];

  static final List<Map<String, dynamic>> workoutPlans = [
    {
      'id': 'p1',
      'title': 'Üst Vücut — Başlangıç',
      'week_day': 'Pazartesi',
      'is_active': true,
      'workout_exercises': [
        {'id': 'e1', 'name': 'Şınav', 'category': 'Güç', 'sets': 3, 'reps': 10, 'rest_sec': 45, 'order_index': 0},
        {'id': 'e2', 'name': 'Plank', 'category': 'Güç', 'duration_sec': 40, 'rest_sec': 30, 'order_index': 1},
        {'id': 'e3', 'name': 'Dips', 'category': 'Güç', 'sets': 3, 'reps': 12, 'rest_sec': 45, 'order_index': 2},
      ],
    },
  ];

  // ── Danışanın koç bağlantıları ───────────────────────────────────────────

  static final List<CoachConnection> _connections = [
    const CoachConnection(
        id: 'dc1', isActive: true, name: 'Dyt. Elif Kaya', role: 'dietitian'),
    const CoachConnection(
        id: 'dc2', isActive: false, name: 'Koç Can Demir', role: 'coach'),
  ];

  static List<CoachConnection> get connections => List.of(_connections);

  static void respond(String id, bool accept) {
    final i = _connections.indexWhere((c) => c.id == id);
    if (i < 0) return;
    if (accept) {
      final c = _connections[i];
      _connections[i] = CoachConnection(
          id: c.id, isActive: true, name: c.name, role: c.role);
    } else {
      _connections.removeAt(i);
    }
  }

  // ── Koçun danışanları ────────────────────────────────────────────────────

  static final List<Map<String, dynamic>> _clients = [
    {..._clientProfile},
    {
      'id': 'demo-c-2', 'full_name': 'Zeynep Arslan', 'role': 'client',
      'kalori_id': 'ZR4P9Q', 'age': 34, 'gender': 'Kadın', 'height': 165,
      'weight': 71.2, 'goal': 'lose', 'daily_tdee': 1650, 'activity_level': 1.375,
    },
    {
      'id': 'demo-c-3', 'full_name': 'Mert Demir', 'role': 'client',
      'kalori_id': 'MD8K2L', 'age': 24, 'gender': 'Erkek', 'height': 182,
      'weight': 74.0, 'goal': 'gain', 'daily_tdee': 3050, 'activity_level': 1.725,
    },
    {
      'id': 'demo-c-4', 'full_name': 'Ayşe Çelik', 'role': 'client',
      'kalori_id': 'AC3N7V', 'age': 41, 'gender': 'Kadın', 'height': 160,
      'weight': 78.5, 'goal': 'lose', 'daily_tdee': 1500, 'activity_level': 1.2,
    },
    {
      'id': 'demo-c-5', 'full_name': 'Can Öztürk', 'role': 'client',
      'kalori_id': 'CO6T1B', 'age': 31, 'gender': 'Erkek', 'height': 175,
      'weight': 80.1, 'goal': 'maintain', 'daily_tdee': 2500, 'activity_level': 1.55,
    },
  ];

  static List<Map<String, dynamic>> get clientConnections => [
        for (var i = 0; i < _clients.length; i++)
          {
            'id': 'conn-$i',
            'status': 'active',
            'created_at': DateTime.now()
                .subtract(Duration(days: 40 - i * 7))
                .toUtc()
                .toIso8601String(),
            'profiles': _clients[i],
          }
      ];

  static final Map<String, String?> _mealFeedback = {};

  static void setMealFeedback(String mealId, String? comment) {
    _mealFeedback[mealId] = comment;
  }

  static MealLog applyFeedback(MealLog m) => _mealFeedback.containsKey(m.id)
      ? m.copyWith(coachComment: _mealFeedback[m.id] ?? '')
      : m;
}
