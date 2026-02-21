import 'dart:convert';
import 'dart:io';

class GroqResponse {
  final String explanation;   // AI açıklaması
  final String? suggestedCommand; // Tavsiye komut (varsa)

  const GroqResponse({
    required this.explanation,
    this.suggestedCommand,
  });
}

class GroqService {
  static const _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.1-8b-instant';

  final String apiKey;
  final String prompt;

  GroqService({required this.apiKey, required this.prompt});

  Future<GroqResponse?> analyze(String command, String output) async {
    try {
      // Prompt içindeki {command} ve {output} yer tutucularını doldur
      final filledPrompt = prompt
          .replaceAll('{command}', command)
          .replaceAll('{output}', output.isEmpty ? '(çıktı yok)' : output);

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(_apiUrl));

      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Authorization', 'Bearer $apiKey');

      final body = jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': filledPrompt}
        ],
        'max_tokens': 300,
        'temperature': 0.3,
      });

      request.write(body);
      final response = await request.close()
          .timeout(const Duration(seconds: 15));

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(responseBody);
      final content = decoded['choices'][0]['message']['content'] as String;

      return _parseResponse(content);
    } catch (_) {
      return null;
    }
  }

  GroqResponse _parseResponse(String content) {
    String explanation = content.trim();
    String? suggestedCommand;

    // "Tavsiye Komut:" satırını ayır
    final lines = content.split('\n');
    final cmdLineIndex = lines.indexWhere(
        (l) => l.trim().startsWith('Tavsiye Komut:'));

    if (cmdLineIndex != -1) {
      // Tavsiye komutu parse et
      final cmdLine = lines[cmdLineIndex].trim();
      suggestedCommand = cmdLine
          .replaceFirst('Tavsiye Komut:', '')
          .trim()
          .replaceAll('`', '') // backtick temizle
          .trim();

      // Açıklamadan komut satırını çıkar
      explanation = lines
          .sublist(0, cmdLineIndex)
          .join('\n')
          .trim();
    }

    return GroqResponse(
      explanation: explanation,
      suggestedCommand: suggestedCommand?.isNotEmpty == true
          ? suggestedCommand
          : null,
    );
  }

  // Bağlantı testi
  Future<bool> testConnection() async {
    try {
      final result = await analyze('echo test', 'test');
      return result != null;
    } catch (_) {
      return false;
    }
  }
}
