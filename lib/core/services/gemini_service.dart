import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Gemini Vision analizinden dönen besin bilgisi.
class FoodAnalysis {
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final String insight;

  const FoodAnalysis({
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.insight,
  });
}

/// Kullanıcıya gösterilebilecek, anlaşılır Türkçe mesaj taşıyan hata.
class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => message;
}

class GeminiService {
  static const Duration _timeout = Duration(seconds: 45);

  static const String _prompt = '''
Sen uzman bir diyetisyensin. Fotoğraftaki yemeği/yemekleri tanı ve tabaktaki toplam porsiyonu tahmin et.
SADECE GEÇERLİ BİR JSON objesi döndür. Markdown blokları (```json) KULLANMA.
Beklenen format:
{
  "name": "Yemek Adı (Türkçe)",
  "calories": 450,
  "protein": 25.5,
  "carbs": 40.0,
  "fat": 12.0,
  "insight": "Kısa, motive edici ve bilgilendirici Türkçe besin notu (max 1 cümle)"
}
Fotoğrafta yiyecek yoksa "name" alanını "Yiyecek bulunamadı" ve tüm sayıları 0 yap.
Değerler tahmini olabilir. Rakamlar DAIMA sayı türünde olsun (string değil).
''';

  /// Fotoğrafı Gemini Vision API'ye gönderir ve besin değerlerini döndürür.
  static Future<FoodAnalysis> analyzeFoodImage(
    String base64Image, {
    String mimeType = 'image/jpeg',
    http.Client? client,
  }) async {
    if (!AppConfig.hasGeminiKey) {
      throw const GeminiException(
        'Gemini API anahtarı tanımlı değil. Uygulamayı '
        '--dart-define=GEMINI_API_KEY=... ile çalıştırın '
        'veya öğünü elle ekleyin.',
      );
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${AppConfig.geminiModel}:generateContent',
    );

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image}
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'responseMimeType': 'application/json',
      }
    };

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              // Anahtar URL yerine başlıkta gönderilir; loglara sızmaz.
              'x-goog-api-key': AppConfig.geminiApiKey,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw GeminiException(_messageForStatus(response.statusCode));
      }
      return parseResponse(response.body);
    } on TimeoutException {
      throw const GeminiException(
          'Analiz zaman aşımına uğradı. Lütfen tekrar deneyin.');
    } on http.ClientException {
      throw const GeminiException(
          'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.');
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// Ham API yanıtını [FoodAnalysis] nesnesine çevirir.
  static FoodAnalysis parseResponse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw const GeminiException(
            'Yapay zeka bu görsel için yanıt üretmedi.');
      }
      final parts = candidates[0]['content']?['parts'] as List?;
      final text = parts?.isNotEmpty == true ? parts![0]['text'] : null;
      if (text is! String) {
        throw const GeminiException('Yapay zeka yanıtı okunamadı.');
      }
      return parseFoodJson(text);
    } on GeminiException {
      rethrow;
    } catch (_) {
      throw const GeminiException('Yapay zeka yanıtı okunamadı.');
    }
  }

  /// Modelin ürettiği JSON metnini ayrıştırır (```json bloklarını tolere eder).
  static FoodAnalysis parseFoodJson(String text) {
    var cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      cleaned = cleaned.substring(start, end + 1);
    }
    final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
    final name = (parsed['name'] as String?)?.trim();
    return FoodAnalysis(
      name: (name == null || name.isEmpty) ? 'Bilinmeyen Yemek' : name,
      calories: toInt(parsed['calories']).clamp(0, 10000),
      protein: toDouble(parsed['protein']).clamp(0, 1000).toDouble(),
      carbs: toDouble(parsed['carbs']).clamp(0, 1000).toDouble(),
      fat: toDouble(parsed['fat']).clamp(0, 1000).toDouble(),
      insight: (parsed['insight'] as String?)?.trim() ?? 'Afiyet olsun!',
    );
  }

  static String _messageForStatus(int status) {
    switch (status) {
      case 400:
        return 'Görsel işlenemedi. Farklı bir fotoğraf deneyin.';
      case 401:
      case 403:
        return 'Gemini API anahtarı geçersiz veya yetkisiz.';
      case 429:
        return 'Çok fazla istek gönderildi. Biraz bekleyip tekrar deneyin.';
      default:
        if (status >= 500) {
          return 'Yapay zeka servisi şu an yanıt vermiyor. Daha sonra deneyin.';
        }
        return 'Beklenmeyen bir hata oluştu (kod $status).';
    }
  }

  static int toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    return double.tryParse(value.toString())?.round() ?? 0;
  }

  static double toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
