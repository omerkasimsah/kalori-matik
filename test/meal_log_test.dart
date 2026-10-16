import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_matik/core/services/supabase_service.dart';
import 'package:kalori_matik/features/auth/screens/auth_validators.dart';
import 'package:kalori_matik/features/history/screens/history_screen.dart';
import 'package:kalori_matik/features/home/models/meal_log.dart';

MealLog _meal(String id, DateTime at, int kcal, {double? p}) =>
    MealLog(id: id, name: 'Yemek $id', calories: kcal, createdAt: at, protein: p);

void main() {
  connectionTests();
  group('MealLog', () {
    test('fromMap Supabase satırını ayrıştırır', () {
      final m = MealLog.fromMap({
        'id': 'abc',
        'name': 'Tost',
        'calories': 320.0,
        'created_at': '2026-10-16T08:05:00Z',
        'protein': '14.5',
        'carbs': 30,
        'fat': null,
      });
      expect(m.id, 'abc');
      expect(m.calories, 320);
      expect(m.protein, 14.5);
      expect(m.carbs, 30.0);
      expect(m.fat, isNull);
      expect(m.createdAt.isUtc, isFalse);
    });

    test('time HH:mm formatında', () {
      final m = _meal('1', DateTime(2026, 1, 2, 7, 4), 100);
      expect(m.time, '07:04');
      expect(m.day, DateTime(2026, 1, 2));
    });
  });

  group('DailyTotal.group', () {
    test('günlere dağıtır, boş günleri sıfırla doldurur', () {
      final now = DateTime(2026, 10, 16, 20);
      final totals = DailyTotal.group([
        _meal('a', DateTime(2026, 10, 16, 9), 400, p: 20),
        _meal('b', DateTime(2026, 10, 16, 13), 600, p: 30),
        _meal('c', DateTime(2026, 10, 14, 12), 500),
        _meal('old', DateTime(2026, 10, 1, 12), 999),
      ], days: 7, now: now);

      expect(totals.length, 7);
      expect(totals.first.date, DateTime(2026, 10, 10));
      expect(totals.last.date, DateTime(2026, 10, 16));
      expect(totals.last.calories, 1000);
      expect(totals.last.protein, 50);
      expect(totals.last.mealCount, 2);
      expect(totals[4].calories, 500); // 14 Ekim
      expect(totals[5].calories, 0); // 15 Ekim
    });

    test('ay geçişlerini doğru sayar', () {
      final totals =
          DailyTotal.group(const [], days: 3, now: DateTime(2026, 3, 1));
      expect(totals.map((t) => t.date).toList(), [
        DateTime(2026, 2, 27),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 1),
      ]);
    });
  });

  group('Geçmiş gruplama', () {
    test('yerel güne göre ve yeniden eskiye gruplar', () {
      final grouped = HistoryScreen.groupByDay([
        _meal('1', DateTime(2026, 10, 16, 21), 100),
        _meal('2', DateTime(2026, 10, 16, 8), 100),
        _meal('3', DateTime(2026, 10, 12, 23, 59), 100),
      ]);
      expect(grouped.keys.toList(),
          [DateTime(2026, 10, 16), DateTime(2026, 10, 12)]);
      expect(grouped[DateTime(2026, 10, 16)]!.length, 2);
    });

    test('gün etiketleri', () {
      final now = DateTime(2026, 10, 16, 10);
      expect(HistoryScreen.dayLabel(DateTime(2026, 10, 16), now), 'Bugün');
      expect(HistoryScreen.dayLabel(DateTime(2026, 10, 15), now), 'Dün');
      expect(HistoryScreen.dayLabel(DateTime(2026, 10, 12), now),
          '12 Ekim, Pazartesi');
    });
  });

  group('Doğrulama ve hata mesajları', () {
    test('e-posta ve şifre doğrulayıcıları', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('abc'), isNotNull);
      expect(AuthValidators.email(' ali@ornek.com '), isNull);
      expect(AuthValidators.password('123'), isNotNull);
      expect(AuthValidators.password('123456'), isNull);
    });

    test('Supabase hata mesajları Türkçeleştirilir', () {
      expect(SupabaseService.authErrorMessage(Exception('Invalid login credentials')),
          'E-posta veya şifre hatalı.');
      expect(SupabaseService.authErrorMessage(Exception('User already registered')),
          contains('zaten bir hesap'));
      expect(SupabaseService.authErrorMessage(Exception('???')),
          contains('tekrar deneyin'));
    });
  });
}

void connectionTests() {
  group('CoachConnection', () {
    test('ad yoksa role göre etiket gösterir', () {
      final c = CoachConnection.fromMap({
        'id': 1,
        'status': 'pending',
        'professional_name': null,
        'professional_role': 'dietitian',
      });
      expect(c.isActive, isFalse);
      expect(c.displayName, 'Diyetisyen');
      final d = CoachConnection.fromMap({
        'id': 2,
        'status': 'active',
        'professional_name': ' Dyt. Elif ',
        'professional_role': 'coach',
      });
      expect(d.isActive, isTrue);
      expect(d.displayName, 'Dyt. Elif');
      expect(d.roleLabel, 'Koç');
    });
  });
}
