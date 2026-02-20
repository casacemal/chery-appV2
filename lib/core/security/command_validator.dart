import '../constants/app_constants.dart';

class CommandValidator {
  static ValidationResult validate(String command) {
    // Boş komut
    if (command.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        error: 'Boş komut',
        level: ValidationLevel.error,
      );
    }

    // Uzunluk kontrolü
    if (command.length > 512) {
      return ValidationResult(
        isValid: false,
        error: 'Komut çok uzun (max 512 karakter)',
        level: ValidationLevel.error,
      );
    }

    final trimmed = command.trim();
    final firstWord = trimmed.split(' ').first.toLowerCase();

    // Whitelist: ilk kelime izin verilen komutlardan biri olmalı
    if (!AppConstants.whitelistCommands.contains(firstWord)) {
      return ValidationResult(
        isValid: false,
        error: 'İzin verilmeyen komut: $firstWord',
        level: ValidationLevel.error,
      );
    }

    // Tehlikeli karakter kontrolü (pipe, chaining)
    for (final char in AppConstants.dangerousChars) {
      if (trimmed.contains(char)) {
        return ValidationResult(
          isValid: false,
          error: 'Tehlikeli karakter tespit edildi: $char',
          level: ValidationLevel.error,
        );
      }
    }

    // Blacklist pattern kontrolü
    for (final pattern in AppConstants.blacklistPatterns) {
      if (trimmed.contains(pattern)) {
        return ValidationResult(
          isValid: false,
          error: 'Tehlikeli komut tespit edildi: $pattern',
          level: ValidationLevel.error,
        );
      }
    }

    // 'su' tam kelime bazlı kontrol
    // "dumpsys", "settings" gibi içinde "su" geçen komutlara izin verir
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.contains('su')) {
      return ValidationResult(
        isValid: false,
        error: 'su komutu direkt kullanılamaz',
        level: ValidationLevel.error,
      );
    }

    // Kritik komutlar - onay gerektirir
    const criticalKeywords = [
      'reboot',
      'setprop persist',
      'pm uninstall',
      'format',
    ];
    for (final keyword in criticalKeywords) {
      if (trimmed.contains(keyword)) {
        return ValidationResult(
          isValid: true,
          warning: 'Bu kritik bir komut. Emin misiniz?',
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
