import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/calorie_calculator.dart';
import '../../../core/services/haptics.dart';
import 'calorie_provider.dart';

/// Günlük su hedefi (ml) — kiloya göre.
final waterGoalProvider = Provider<int>((ref) {
  return CalorieCalculator.waterGoalMl(ref.watch(userWeightProvider));
});

/// Bugün içilen su (ml). Cihazda, kullanıcı ve gün bazında saklanır.
final waterIntakeProvider =
    StateNotifierProvider<WaterNotifier, int>((ref) {
  return WaterNotifier(ref.watch(currentUserIdProvider));
});

class WaterNotifier extends StateNotifier<int> {
  final String? userId;

  WaterNotifier(this.userId) : super(0) {
    _load();
  }

  String get _key {
    final n = DateTime.now();
    return 'water_${userId ?? 'guest'}_${n.year}-${n.month}-${n.day}';
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) state = prefs.getInt(_key) ?? 0;
    } catch (_) {}
  }

  /// Gün değiştiyse sayacı o günün değerine çeker.
  Future<void> refresh() => _load();

  Future<void> add(int ml) async {
    if (ml > 0) Haptics.light();
    state = (state + ml).clamp(0, 10000);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, state);
    } catch (_) {}
  }
}
