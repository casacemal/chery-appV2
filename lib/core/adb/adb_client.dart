import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../shared/models/models.dart';
import '../logger/black_box_logger.dart';
import '../security/command_validator.dart';

/// Enhanced ADB Client with ChangeNotifier and extensive logging
class ADBClient extends ChangeNotifier {
  static final ADBClient _instance = ADBClient._internal();
  factory ADBClient() => _instance;
  ADBClient._internal();

  String? _connectedIp;
  int? _connectedPort;
  bool _useRoot = false;

  final _logger = BlackBoxLogger();
  final _rateLimiter = RateLimiter();

  bool get isConnected => _connectedIp != null;
  String? get connectedDevice => _connectedIp;
  bool get useRoot => _useRoot;

  // ─── Root Yönetimi ───────────────────────────────────────────────────────

  Future<bool> enableRoot() async {
    if (!isConnected) return false;

    try {
      final result = await Process.run(
        'adb',
        ['-s', '$_connectedIp:$_connectedPort', 'root'],
      ).timeout(const Duration(seconds: 10));

      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();

      // "adbd is already running as root" veya "restarting adbd as root" başarılı sayılır.
      // "Production builds" veya "cannot run as root" başarısız.
      final isSuccess = result.exitCode == 0 &&
          !stdout.contains('cannot') &&
          !stdout.contains('Production builds') &&
          !stderr.contains('cannot') &&
          !stderr.contains('Production builds');

      if (isSuccess) {
        // ADB daemon yeniden başlıyor, bağlantının yerine oturması için bekle
        if (stdout.contains('restarting')) {
          await Future.delayed(const Duration(seconds: 2));
        }

        _useRoot = true;
        notifyListeners();

        await _logger.log(
          operation: LogOperation.connection,
          details: 'Root mode etkinleştirildi: $stdout',
          status: LogStatus.success,
          deviceIp: _connectedIp,
        );
        return true;
      } else {
        // adb root başarısız → Magisk/SuperSU üzerinden su -c dene
        final suCheck = await _checkSuAvailable();
        if (suCheck) {
          _useRoot = true;
          notifyListeners();

          await _logger.log(
            operation: LogOperation.connection,
            details: 'Root mode su üzerinden etkinleştirildi',
            status: LogStatus.success,
            deviceIp: _connectedIp,
          );
          return true;
        }

        await _logger.log(
          operation: LogOperation.error,
          details: 'Root mode başarısız. stdout: $stdout | stderr: $stderr',
          status: LogStatus.failed,
          deviceIp: _connectedIp,
        );
        return false;
      }
    } catch (e) {
      await _logger.log(
        operation: LogOperation.error,
        details: 'Root mode hatası: $e',
        status: LogStatus.failed,
        deviceIp: _connectedIp,
      );
      return false;
    }
  }

  /// Cihazda su binary'si var mı ve çalışıyor mu kontrol eder
  Future<bool> _checkSuAvailable() async {
    try {
      final result = await Process.run(
        'adb',
        ['-s', '$_connectedIp:$_connectedPort', 'shell', 'su -c "id"'],
      ).timeout(const Duration(seconds: 5));

      final output = result.stdout.toString();
      // "uid=0(root)" dönüyorsa su çalışıyor
      return result.exitCode == 0 && output.contains('uid=0');
    } catch (_) {
      return false;
    }
  }

  void disableRoot() {
    _useRoot = false;
    notifyListeners();
  }

  // ─── Bağlantı ────────────────────────────────────────────────────────────

  Future<bool> connect(String ip, int port) async {
    // IP formatı basit doğrulama
    final ipRegex = RegExp(
        r'^((25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(25[0-5]|2[0-4]\d|[01]?\d\d?)$');
    if (!ipRegex.hasMatch(ip) || port < 1 || port > 65535) {
      await _logger.log(
        operation: LogOperation.connection,
        details: 'Geçersiz IP veya port: $ip:$port',
        status: LogStatus.failed,
        deviceIp: ip,
      );
      return false;
    }

    try {
      // Önce TCP ile port açık mı kontrol et
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );
      await socket.close();

      // Gerçek ADB bağlantısını kur ve doğrula
      final result = await Process.run(
        'adb',
        ['connect', '$ip:$port'],
      ).timeout(const Duration(seconds: 10));

      final stdout = result.stdout.toString().trim();

      // "connected to x.x.x.x:port" veya "already connected" başarılı sayılır
      final isSuccess = result.exitCode == 0 &&
          (stdout.contains('connected to') ||
              stdout.contains('already connected'));

      if (isSuccess) {
        _connectedIp = ip;
        _connectedPort = port;

        await _logger.log(
          operation: LogOperation.connection,
          details: 'Bağlandı: $ip:$port | $stdout',
          status: LogStatus.success,
          deviceIp: ip,
        );
        notifyListeners();
        return true;
      } else {
        await _logger.log(
          operation: LogOperation.connection,
          details: 'ADB bağlantısı reddedildi: $stdout',
          status: LogStatus.failed,
          deviceIp: ip,
        );
        return false;
      }
    } catch (e) {
      await _logger.log(
        operation: LogOperation.connection,
        details: 'Bağlantı hatası: $e',
        status: LogStatus.failed,
        deviceIp: ip,
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedIp != null) {
      // ADB bağlantısını da düzgün kapat
      try {
        await Process.run(
          'adb',
          ['disconnect', '$_connectedIp:$_connectedPort'],
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}

      await _logger.log(
        operation: LogOperation.disconnection,
        details: 'Bağlantı kesildi: $_connectedIp',
        status: LogStatus.success,
        deviceIp: _connectedIp,
      );
    }

    _connectedIp = null;
    _connectedPort = null;
    _useRoot = false;
    notifyListeners();
  }

  // ─── Komut Çalıştırma ────────────────────────────────────────────────────

  Future<CommandResult> executeCommand(String command) async {
    if (!isConnected) {
      return CommandResult(
        success: false,
        command: command,
        output: '',
        error: 'Cihaz bağlı değil',
      );
    }

    if (!_rateLimiter.canExecute()) {
      return CommandResult(
        success: false,
        command: command,
        output: '',
        error: 'Çok fazla istek. Lütfen bekleyin.',
      );
    }

    final validation = CommandValidator.validate(command);
    if (!validation.isValid) {
      await _logger.log(
        operation: LogOperation.command,
        details: 'Engellendi: ${validation.error}',
        status: LogStatus.failed,
        command: command,
        deviceIp: _connectedIp,
      );
      return CommandResult(
        success: false,
        command: command,
        output: '',
        error: validation.error,
      );
    }

    try {
      // ✅ Root mode aktifse su -c ile sarmala
      // adb root (daemon root) kullanılıyorsa düz komut gönderilir.
      // Magisk/SuperSU (su -c) kullanılıyorsa komut sarmalanır.
      final bool isDaemonRoot = _useRoot && await _isDaemonRoot();
      final String actualCommand =
          (_useRoot && !isDaemonRoot) ? 'su -c "$command"' : command;

      final result = await Process.run(
        'adb',
        ['-s', '$_connectedIp:$_connectedPort', 'shell', actualCommand],
      ).timeout(const Duration(seconds: 15));

      final success = result.exitCode == 0;
      final output = result.stdout.toString();
      final error = result.stderr.toString();
      final combinedOutput =
          output + (error.isNotEmpty ? '\nERROR: $error' : '');

      await _logger.log(
        operation: LogOperation.command,
        details: 'Komut çalıştırıldı${_useRoot ? " [ROOT]" : ""}',
        status: success ? LogStatus.success : LogStatus.failed,
        command: actualCommand,
        output: combinedOutput,
        deviceIp: _connectedIp,
      );

      return CommandResult(
        success: success,
        command: actualCommand,
        output: output,
        error: error.isNotEmpty ? error : (success ? null : 'Bilinmeyen hata'),
      );
    } catch (e) {
      await _logger.log(
        operation: LogOperation.error,
        details: 'ADB Hatası: $e',
        status: LogStatus.failed,
        command: command,
        deviceIp: _connectedIp,
      );
      return CommandResult(
        success: false,
        command: command,
        output: '',
        error: e.toString(),
      );
    }
  }

  /// ADB daemon'ın root olarak çalışıp çalışmadığını kontrol eder
  Future<bool> _isDaemonRoot() async {
    try {
      final result = await Process.run(
        'adb',
        ['-s', '$_connectedIp:$_connectedPort', 'shell', 'id'],
      ).timeout(const Duration(seconds: 5));
      return result.stdout.toString().contains('uid=0');
    } catch (_) {
      return false;
    }
  }

  // ─── APK & İzin ──────────────────────────────────────────────────────────

  Future<CommandResult> installAPK(String apkPath) async {
    if (!isConnected) {
      return CommandResult(
        success: false,
        command: 'install',
        output: '',
        error: 'Cihaz bağlı değil',
      );
    }

    try {
      final result = await Process.run(
        'adb',
        [
          '-s',
          '$_connectedIp:$_connectedPort',
          'install',
          '-r',
          '-g',
          apkPath
        ],
      ).timeout(const Duration(minutes: 5));

      final success = result.exitCode == 0;
      final output =
          result.stdout.toString() + result.stderr.toString();

      await _logger.log(
        operation: LogOperation.apkInstall,
        details: 'APK kurulumu: $apkPath',
        status: success ? LogStatus.success : LogStatus.failed,
        command: 'install ${apkPath.split('/').last}',
        output: output,
        deviceIp: _connectedIp,
      );

      return CommandResult(
        success: success,
        command: 'install $apkPath',
        output: output,
        error: success ? null : 'Kurulum başarısız: $output',
      );
    } catch (e) {
      return CommandResult(
        success: false,
        command: 'install',
        output: '',
        error: e.toString(),
      );
    }
  }

  Future<bool> grantPermission(
      String packageName, String permission) async {
    final result =
        await executeCommand('pm grant $packageName $permission');
    await _logger.log(
      operation: LogOperation.permissionGrant,
      details: '$packageName - $permission',
      status: result.success ? LogStatus.success : LogStatus.failed,
      deviceIp: _connectedIp,
    );
    return result.success;
  }

  Future<List<String>> getInstalledPackages() async {
    final result = await executeCommand('pm list packages -3');
    if (!result.success) return [];
    return result.output
        .split('\n')
        .where((line) => line.startsWith('package:'))
        .map((line) => line.replaceFirst('package:', '').trim())
        .where((pkg) => pkg.isNotEmpty)
        .toList();
  }
}
