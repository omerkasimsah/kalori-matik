import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_matik/core/services/notification_service.dart';

void main() {
  test('hiçbir bildirim açık değilse plan boş', () {
    expect(NotificationService.buildSchedule(const NotificationSettings()), isEmpty);
  });

  test('öğün ve su hatırlatıcıları 3er adet, kimlikler benzersiz', () {
    final list = NotificationService.buildSchedule(
        const NotificationSettings(meals: true, water: true));
    expect(list.length, 6);
    expect(list.map((e) => e.id).toSet().length, 6);
    expect(list.every((e) => e.weekday == null), isTrue);
  });

  test('antrenman hatırlatıcısı: plan yoksa her gün, varsa yalnızca plan günleri', () {
    const s = NotificationSettings(workout: true, workoutHour: 7, workoutMinute: 15);
    final daily = NotificationService.buildSchedule(s);
    expect(daily.length, 1);
    expect(daily.single.weekday, isNull);
    expect(daily.single.hour, 7);
    expect(daily.single.minute, 15);

    final planned =
        NotificationService.buildSchedule(s, trainingWeekdays: [1, 3, 5, 3]);
    expect(planned.map((e) => e.weekday).toList()..sort(), [1, 3, 5]);
    expect(planned.map((e) => e.id).toSet().length, 3);
  });
}
