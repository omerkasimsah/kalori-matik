/// Uygulama yapılandırması.
///
/// Tüm değerler derleme anında `--dart-define` (veya `--dart-define-from-file`)
/// ile verilebilir. Supabase anon anahtarı istemcide bulunması amaçlanan,
/// RLS ile korunan bir anahtardır; bu yüzden varsayılan değer olarak tutulur.
/// Gemini anahtarı ise gizlidir ve ASLA koda yazılmamalıdır.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lxenaupsykwlwlebwcwg.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx4ZW5hdXBzeWt3bHdsZWJ3Y3dnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMTAyNDQsImV4cCI6MjA4ODc4NjI0NH0.JC6Mtnk2Df6Ar0oczQQ1cLClwe9nI5pPnfrbvZz5DAM',
  );

  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-2.5-flash',
  );

  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
}
