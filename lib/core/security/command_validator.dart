import '../constants/app_constants.dart';

class CommandValidator {
  /// Validates if a command is safe to execute
  static ValidationResult validate(String command) {
    // Length check
    if (command.length > 512) {
      return ValidationResult(
        isValid: false,
        error: 'Komut çok uzun (max 512 karakter)',
        level: ValidationLevel.error,
      );
    }

    // Empty command
    if (command.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        error: 'Boş komut',
        level: ValidationLevel.error,
      );
    }

    final trimmed = command.trim();
    final firstWord = trimmed.split(' ').first;

    // Whitelist check
    if (!AppConstants.whitelistCommands.contains(firstWord)) {
      return ValidationResult(
        isValid: false,
        error: 'İzin verilmeyen komut: $firstWord',
        level: ValidationLevel.error,
      );
    }

    // Blacklist pattern check
    for (final pattern in AppConstants.blacklistPatterns) {
      if (trimmed.contains(pattern)) {
        return ValidationResult(
          isValid: false,
          error: 'Tehlikeli karakter dizisi tespit edildi: $pattern',
          level: ValidationLevel.error,
        );
      }
    }

    // SQL Injection check
    if (trimmed.contains("'") || trimmed.contains('"') || trimmed.contains('`')) {
      return ValidationResult(
        isValid: false,
        error: 'Şüpheli karakter (tırnak işareti)',
        level: ValidationLevel.warning,
      );
    }

    // Critical commands - require confirmation
    final criticalKeywords = ['reboot', 'setprop persist', 'pm uninstall', 'format'];
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

enum ValidationLevel {
  success,
  warning,
  error,
}

class RateLimiter {
  final int maxRequestsPerSecond;
  final List<DateTime> _requestTimes = [];

  RateLimiter({this.maxRequestsPerSecond = 5});

  bool canExecute() {
    final now = DateTime.now();
    final oneSecondAgo = now.subtract(const Duration(seconds: 1));
    
    // Remove old requests
    _requestTimes.removeWhere((time) => time.isBefore(oneSecondAgo));
    
    if (_requestTimes.length >= maxRequestsPerSecond) {
      return false;
    }
    
    _requestTimes.add(now);
    return true;
  }

  void reset() {
    _requestTimes.clear();
  }
}
