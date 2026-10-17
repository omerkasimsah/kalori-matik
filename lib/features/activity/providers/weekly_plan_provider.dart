import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/providers/calorie_provider.dart';
import '../data/plan_generator.dart';

/// Kullanıcının haftalık antrenman planı. Cihazda saklanır.
final weeklyPlanProvider =
    StateNotifierProvider<WeeklyPlanNotifier, WeeklyPlan?>((ref) {
  return WeeklyPlanNotifier(ref.watch(currentUserIdProvider));
});

class WeeklyPlanNotifier extends StateNotifier<WeeklyPlan?> {
  final String? userId;

  WeeklyPlanNotifier(this.userId) : super(null) {
    _load();
  }

  String get _key => 'weekly_plan_${userId ?? 'guest'}';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final plan = WeeklyPlan.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
      if (mounted && plan.days.isNotEmpty) state = plan;
    } catch (_) {
      // Bozuk kayıt: planı yok say
    }
  }

  Future<void> generate(PlanRequest request) async {
    final plan = PlanGenerator.generate(request);
    state = plan;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(plan.toJson()));
    } catch (_) {}
  }

  Future<void> clear() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
