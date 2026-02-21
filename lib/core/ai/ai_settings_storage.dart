import 'package:shared_preferences/shared_preferences.dart';

class AISettingsStorage {
  static const _keyApiKey = 'groq_api_key';
  static const _keyPrompt = 'groq_prompt';

  static const String defaultPrompt =
      '''Sen bir Chery araç multimedya sistemi uzmanısın.
ADB shell komutu çalıştırıldı ve aşağıdaki sonuç geldi.
Sonucu 2-3 cümleyle kısaca açıkla.
Eğer bir sorun varsa veya yapılabilecek bir işlem varsa "Tavsiye Komut:" başlığıyla sadece tek bir ADB shell komutu öner.
Komut yoksa "Tavsiye Komut:" satırını ekleme.
Cevabını Türkçe ver.

Komut: {command}
Çıktı: {output}''';

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, key);
  }

  Future<String> getPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPrompt) ?? defaultPrompt;
  }

  Future<void> savePrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrompt, prompt);
  }

  Future<void> resetPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrompt, defaultPrompt);
  }
}
