import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // Google Gemini API Anahtarı ve İstek Endpoint'i (Uç noktası)
  // Güvenlik için ortam değişkeninden veya dart-define ile okunur.
  static const String _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY_HERE',
  );
  static const String _apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Kamera modülünden gelen fotoğrafın Base64 formatını alır ve resmi analiz etmesi için Gemini Vision API'ye POST isteği atar.
  /// İşlem başarılı olursa formatlanmış veriyi (Yemek Adı, Kalori, Makrolar) JSON objesi (Map) olarak döndürür.
  static Future<Map<String, dynamic>> analyzeFoodImage(String base64Image) async {
    final url = Uri.parse('$_apiUrl?key=$_apiKey');

    const prompt = '''
Sen uzman bir diyetisyensin. Fotoğraftaki yemeği tanı ve tahmini porsiyonunu belirle.
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
Değerler tahmini olabilir. Rakamlar DAIMA sayı türünde olsun (string değil).
''';

    final Map<String, dynamic> requestBody = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inline_data": {
                "mime_type": "image/jpeg",
                "data": base64Image,
              }
            }
          ]
        }
      ],
      "generationConfig": {
        "temperature": 0.4,
        "responseMimeType": "application/json",
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // API'den dönen JSON hiyerarşisi içerisinden asıl metni çıkarıyoruz.
        String contentText =
            data['candidates'][0]['content']['parts'][0]['text'];

        // Veri Temizleme: Eğer yapay zeka Markdown formatında (```json) yanıt döndürdüyse
        // JSON parse işleminin çökmemesi için bu etiketleri temizliyoruz.
        contentText = contentText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed = jsonDecode(contentText) as Map<String, dynamic>;

        // Tip güvencesi
        return {
          'name': parsed['name'] ?? 'Bilinmeyen Yemek',
          'calories': _toInt(parsed['calories']),
          'protein': _toDouble(parsed['protein']),
          'carbs': _toDouble(parsed['carbs']),
          'fat': _toDouble(parsed['fat']),
          'insight': parsed['insight'] ?? 'Afiyet olsun!',
        };
      } else {
        throw Exception('Gemini API Hatası: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Analiz sırasında hata oluştu: $e');
    }
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
