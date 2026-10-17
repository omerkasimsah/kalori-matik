import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Kullanıcının bildirim tercihleri.
class NotificationSettings {
  final bool meals;
  final bool water;
  final bool workout;
  final bool haptics;
  final int workoutHour;
  final int workoutMinute;

  const NotificationSettings({
    this.meals = false,
    this.water = false,
    this.workout = false,
    this.haptics = true,
    this.workoutHour = 18,
    this.workoutMinute = 0,
  });

  NotificationSettings copyWith({
    bool? meals,
    bool? water,
    bool? workout,
    bool? haptics,
    int? workoutHour,
    int? workoutMinute,
  }) =>
      NotificationSettings(
        meals: meals ?? this.meals,
        water: water ?? this.water,
        workout: workout ?? this.workout,
        haptics: haptics ?? this.haptics,
        workoutHour: workoutHour ?? this.workoutHour,
        workoutMinute: workoutMinute ?? this.workoutMinute,
      );

  bool get anyEnabled => meals || water || workout;
}

/// Planlanacak tek bir hatırlatıcı.
class ReminderSpec {
  final int id;
  final String title;
  final String body;
  final int hour;
  final int minute;

  /// 1 = Pazartesi … 7 = Pazar; null ise her gün.
  final int? weekday;

  const ReminderSpec({
    required this.id,
    required this.title,
    required this.body,
    required this.hour,
    required this.minute,
    this.weekday,
  });
}

/// Yerel (internetsiz) hatırlatıcı bildirimleri.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Sabit kimlik aralıkları
  static const _mealBase = 100;
  static const _waterBase = 200;
  static const _workoutBase = 300;

  static const _mealTexts = [
    (8, 30, 'Kahvaltı vakti ☀️', 'Güne güçlü başla; kahvaltını kaydetmeyi unutma.'),
    (13, 0, 'Öğle yemeği', 'Öğününü fotoğrafla, kalorin otomatik hesaplansın.'),
    (19, 30, 'Akşam yemeği', 'Günü kapatmadan akşam öğününü ekle.'),
  ];

  static const _waterTexts = [
    (11, 0, 'Su iç 💧', 'Bir bardak su iç ve kaydet.'),
    (15, 0, 'Su molası', 'Günün yarısı geçti; su hedefin nasıl?'),
    (18, 0, 'Su hedefine az kaldı', 'Akşam olmadan bir bardak daha!'),
  ];

  static Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      tz_data.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    }
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    _ready = true;
  }

  /// Android 13+ bildirim izni. İzin verildiyse true.
  static Future<bool> requestPermission() async {
    if (!_supported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Ayarlara göre tüm hatırlatıcıları yeniden planlar.
  /// [trainingWeekdays]: haftalık programdaki antrenman günleri (boşsa her gün).
  static Future<void> apply(
    NotificationSettings s, {
    List<int> trainingWeekdays = const [],
  }) async {
    if (!_supported) return;
    await init();
    await _plugin.cancelAll();
    if (!s.anyEnabled) return;

    for (final r in buildSchedule(s, trainingWeekdays: trainingWeekdays)) {
      await _schedule(r);
    }
  }

  /// Saf mantık: hangi hatırlatıcıların planlanacağı (test edilebilir).
  static List<ReminderSpec> buildSchedule(
    NotificationSettings s, {
    List<int> trainingWeekdays = const [],
  }) {
    final list = <ReminderSpec>[];
    if (s.meals) {
      for (var i = 0; i < _mealTexts.length; i++) {
        final t = _mealTexts[i];
        list.add(ReminderSpec(
            id: _mealBase + i, hour: t.$1, minute: t.$2, title: t.$3, body: t.$4));
      }
    }
    if (s.water) {
      for (var i = 0; i < _waterTexts.length; i++) {
        final t = _waterTexts[i];
        list.add(ReminderSpec(
            id: _waterBase + i, hour: t.$1, minute: t.$2, title: t.$3, body: t.$4));
      }
    }
    if (s.workout) {
      final days =
          trainingWeekdays.isEmpty ? [null] : trainingWeekdays.toSet().toList();
      for (final d in days) {
        list.add(ReminderSpec(
          id: _workoutBase + (d ?? 0),
          hour: s.workoutHour,
          minute: s.workoutMinute,
          weekday: d,
          title: 'Antrenman zamanı 💪',
          body: d == null
              ? 'Bugün hareket etmeyi unutma.'
              : 'Bugün antrenman günün. Programını başlat!',
        ));
      }
    }
    return list;
  }

  static tz.TZDateTime _nextInstance(int hour, int minute, int? weekday) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (t.isBefore(now) || (weekday != null && t.weekday != weekday)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  static Future<void> _schedule(ReminderSpec r) async {
    await _plugin.zonedSchedule(
      r.id,
      r.title,
      r.body,
      _nextInstance(r.hour, r.minute, r.weekday),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Hatırlatıcılar',
          channelDescription: 'Öğün, su ve antrenman hatırlatıcıları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          enableVibration: true,
        ),
      ),
      // Tam zamanlı alarm izni gerektirmez; birkaç dakika sapabilir.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: r.weekday == null
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelAll() async {
    if (!_supported) return;
    await init();
    await _plugin.cancelAll();
  }
}
