import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/haptics.dart';
import '../../../core/services/notification_service.dart';
import '../../activity/providers/weekly_plan_provider.dart';

/// Bildirim ve titreşim tercihleri (cihazda saklanır).
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        (ref) => NotificationSettingsNotifier());

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = NotificationSettings(
        meals: p.getBool('n_meals') ?? false,
        water: p.getBool('n_water') ?? false,
        workout: p.getBool('n_workout') ?? false,
        haptics: p.getBool('n_haptics') ?? true,
        workoutHour: p.getInt('n_workout_h') ?? 18,
        workoutMinute: p.getInt('n_workout_m') ?? 0,
      );
      Haptics.enabled = s.haptics;
      if (mounted) state = s;
    } catch (_) {}
  }

  Future<void> update(NotificationSettings s) async {
    state = s;
    Haptics.enabled = s.haptics;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('n_meals', s.meals);
      await p.setBool('n_water', s.water);
      await p.setBool('n_workout', s.workout);
      await p.setBool('n_haptics', s.haptics);
      await p.setInt('n_workout_h', s.workoutHour);
      await p.setInt('n_workout_m', s.workoutMinute);
    } catch (_) {}
  }
}

/// Ayarlar veya haftalık plan değişince hatırlatıcıları yeniden planlar.
/// Ana sayfa bu provider'ı izleyerek canlı tutar.
final notificationSyncProvider = Provider<void>((ref) {
  final settings = ref.watch(notificationSettingsProvider);
  final plan = ref.watch(weeklyPlanProvider);
  NotificationService.apply(
    settings,
    trainingWeekdays: plan?.days.map((d) => d.weekday).toList() ?? const [],
  );
});
