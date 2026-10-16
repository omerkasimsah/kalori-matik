import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/providers/calorie_provider.dart';
import '../data/sports.dart';

/// Kaydedilmiş bir aktivite (spor veya tamamlanan antrenman).
class ActivityEntry {
  final String id;
  final String title;
  final String sportId;
  final int minutes;
  final int calories;
  final DateTime at;

  const ActivityEntry({
    required this.id,
    required this.title,
    required this.sportId,
    required this.minutes,
    required this.calories,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sportId': sportId,
        'minutes': minutes,
        'calories': calories,
        'at': at.toIso8601String(),
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        sportId: j['sportId'] as String,
        minutes: (j['minutes'] as num).toInt(),
        calories: (j['calories'] as num).toInt(),
        at: DateTime.parse(j['at'] as String),
      );

  Sport get sport => sportById(sportId);
}

/// Bugünkü kayıtlı aktiviteler. Cihazda, kullanıcı ve gün bazında saklanır.
final activityLogProvider =
    StateNotifierProvider<ActivityLogNotifier, List<ActivityEntry>>((ref) {
  return ActivityLogNotifier(ref.watch(currentUserIdProvider));
});

/// Kayıtlı aktivitelerden yakılan toplam kalori.
final loggedActivityCaloriesProvider = Provider<int>((ref) {
  return ref.watch(activityLogProvider).fold(0, (s, e) => s + e.calories);
});

class ActivityLogNotifier extends StateNotifier<List<ActivityEntry>> {
  final String? userId;

  ActivityLogNotifier(this.userId) : super(const []) {
    refresh();
  }

  String get _key {
    final n = DateTime.now();
    return 'activity_${userId ?? 'guest'}_${n.year}-${n.month}-${n.day}';
  }

  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      final list = raw == null
          ? <ActivityEntry>[]
          : (jsonDecode(raw) as List)
              .map((e) => ActivityEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList();
      if (mounted) state = list;
    } catch (_) {
      if (mounted) state = const [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> add({
    required String title,
    required Sport sport,
    required int minutes,
    required double weightKg,
  }) async {
    final entry = ActivityEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      sportId: sport.id,
      minutes: minutes,
      calories: sport.caloriesFor(minutes: minutes, weightKg: weightKg),
      at: DateTime.now(),
    );
    state = [entry, ...state];
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }
}
