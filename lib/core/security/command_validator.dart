import '../constants/app_constants.dart';

class CommandValidator {
  static ValidationResult validate(String command) {
    if (command.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        error: 'Komut boş olamaz.',
        level: ValidationLevel.error,
      );
    }

    if (command.length > 512) {
      return ValidationResult(
        isValid: false,
        error: 'Komut çok uzun (max 512 karakter).',
        level: ValidationLevel.error,
      );
    }

    final trimmed = command.trim();
    final firstWord = trimmed.split(' ').first.toLowerCase();

    // ── Whitelist: ilk kelime izin verilenlerden biri olmalı
    if (!AppConstants.whitelistCommands.contains(firstWord)) {
      return ValidationResult(
        isValid: false,
        error: '"$firstWord" komutu bu sistemde desteklenmiyor.\n\n'
            'İzin verilen komutlar:\n'
            '• input keyevent / tap / swipe / text\n'
            '• am start / force-stop / broadcast\n'
            '• pm list / grant / enable / disable / clear\n'
            '• settings get / put (global, system, secure)\n'
            '• getprop / setprop\n'
            '• wm size / density\n'
            '• dumpsys / service / cmd\n'
            '• svc power / wifi / bluetooth\n'
            '• screencap / logcat / reboot\n'
            '• ls / ps / df / cat / id',
        level: ValidationLevel.error,
      );
    }

    // ── Tehlikeli karakterler (injection önlemi)
    for (final char in AppConstants.dangerousChars) {
      if (trimmed.contains(char)) {
        return ValidationResult(
          isValid: false,
          error: 'Güvenlik: "$char" karakteri kullanılamaz.\n'
              'Her satıra yalnızca tek bir komut yazın.',
          level: ValidationLevel.error,
        );
      }
    }

    // ── Blacklist pattern kontrolü
    for (final pattern in AppConstants.blacklistPatterns) {
      if (trimmed.toLowerCase().contains(pattern.toLowerCase())) {
        return ValidationResult(
          isValid: false,
          error: 'Tehlikeli komut engellendi: "$pattern"\n'
              'Bu komut araç sistemine zarar verebilir.',
          level: ValidationLevel.error,
        );
      }
    }

    // ── "su" tek başına kullanılamaz (root shell zaten açık tutuluyor)
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 1 && words.first == 'su') {
      return ValidationResult(
        isValid: false,
        error: '"su" komutunu doğrudan göndermeyin.\n'
            'Root işlemleri için ayarlar ekranından\n'
            '"Root Modu Etkinleştir" seçeneğini kullanın.',
        level: ValidationLevel.error,
      );
    }

    // ── Kritik komutlar: onay gerektirir
    const criticalKeywords = [
      'reboot',
      'setprop persist',
      'pm uninstall',
      'pm disable',
      'pm clear',
      'wm size',
      'wm density',
    ];
    for (final keyword in criticalKeywords) {
      if (trimmed.toLowerCase().contains(keyword)) {
        return ValidationResult(
          isValid: true,
          warning: '"${keyword.toUpperCase()}" kritik bir komuttur.\n'
              'Araç sistemi etkilenebilir. Devam etmek istiyor musunuz?',
          level: ValidationLevel.warning,
          requiresConfirmation: true,
        );
      }
    }

    return ValidationResult(isValid: true, level: ValidationLevel.success);
  }
}

class ValidationResult {
  final bool isValid;
  final String? error;
  final String? warning;
  final ValidationLevel level;
  final bool requiresConfirmation;

  ValidationResult({
    required this.isValid,
    this.error,
    this.warning,
    required this.level,
    this.requiresConfirmation = false,
  });
}

enum ValidationLevel { success, warning, error }

class RateLimiter {
  final int maxRequestsPerSecond;
  final List<DateTime> _requestTimes = [];

  RateLimiter({this.maxRequestsPerSecond = 5});

  bool canExecute() {
    final now = DateTime.now();
    final oneSecondAgo = now.subtract(const Duration(seconds: 1));
    _requestTimes.removeWhere((t) => t.isBefore(oneSecondAgo));
    if (_requestTimes.length >= maxRequestsPerSecond) return false;
    _requestTimes.add(now);
    return true;
  }

  void reset() => _requestTimes.clear();
}
