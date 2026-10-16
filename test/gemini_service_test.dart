import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalori_matik/core/services/gemini_service.dart';

String _apiBody(String text) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    });

void main() {
  group('GeminiService.parseFoodJson', () {
    test('düz JSON', () {
      final r = GeminiService.parseFoodJson(
          '{"name":"Mercimek Çorbası","calories":180,"protein":9.5,"carbs":28,"fat":4,"insight":"Lif kaynağı"}');
      expect(r.name, 'Mercimek Çorbası');
      expect(r.calories, 180);
      expect(r.protein, 9.5);
      expect(r.carbs, 28.0);
      expect(r.fat, 4.0);
      expect(r.insight, 'Lif kaynağı');
    });

    test('markdown bloğu ve çevresindeki metin temizlenir', () {
      final r = GeminiService.parseFoodJson(
          'Sonuç:\n```json\n{"name":"Pilav","calories":"350","protein":"6","carbs":70,"fat":5}\n```');
      expect(r.name, 'Pilav');
      expect(r.calories, 350);
      expect(r.protein, 6.0);
      expect(r.insight, 'Afiyet olsun!');
    });

    test('ondalıklı kalori yuvarlanır, negatif değerler sıfırlanır', () {
      final r = GeminiService.parseFoodJson(
          '{"name":"","calories":250.6,"protein":-3,"carbs":null,"fat":2}');
      expect(r.name, 'Bilinmeyen Yemek');
      expect(r.calories, 251);
      expect(r.protein, 0);
      expect(r.carbs, 0);
    });
  });

  group('GeminiService.parseResponse', () {
    test('API yanıtından metni çıkarır', () {
      final r = GeminiService.parseResponse(_apiBody(
          '{"name":"Elma","calories":95,"protein":0.5,"carbs":25,"fat":0.3}'));
      expect(r.name, 'Elma');
      expect(r.calories, 95);
    });

    test('aday yoksa anlaşılır hata', () {
      expect(
        () => GeminiService.parseResponse(jsonEncode({'candidates': []})),
        throwsA(isA<GeminiException>()),
      );
    });

    test('bozuk JSON anlaşılır hata', () {
      expect(
        () => GeminiService.parseResponse(_apiBody('bu bir json değil')),
        throwsA(isA<GeminiException>()),
      );
    });
  });

  test('anahtar ve sunucu yoksa kullanıcıya anlaşılır hata verir', () async {
    await expectLater(
      GeminiService.analyzeFoodImage('AAAA'),
      throwsA(isA<GeminiException>()),
    );
  });
}
