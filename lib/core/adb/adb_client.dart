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

  Future<bool> enableRoot() async {
    if (!isConnected) {
      return false;
    }

    try {
      final result = await Process.run(
        'adb',
        ['-s', '$_connectedIp:$_connectedPort', 'root'],
      ).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0) {
        _useRoot = true;
        notifyListeners();

        await _logger.log(
          operation: LogOperation.connection,
          details: 'Root mode etkinleştirildi',
          status: LogStatus.success,
          deviceIp: _connectedIp,
        );
        return true;
      } else {
        await _logger.log(
          operation: LogOperation.error,
          details: 'Root mode başarısız: ${result.stderr}',
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

  void disableRoot() {
    _useRoot = false;
    notifyListeners();
  }

  Future<bool> connect(String ip, int port) async {
    try {
      final socket =
          await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      await socket.close();

      _connectedIp = ip;
      _connectedPort = port;

      await _logger.log(
        operation: LogOperation.connection,
        details: 'Connected to $ip:$port',
        status: LogStatus.success,
        deviceIp: ip,
      );

      notifyListeners();
      return true;
    } catch (e) {
      await _logger.log(
        operation: LogOperation.connection,
        details: 'Failed to connect: $e',
        status: LogStatus.failed,
        deviceIp: ip,
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedIp != null) {
      await _logger.log(
        operation: LogOperation.disconnection,
        details: 'Disconnected from $_connectedIp',
        status: LogStatus.success,
        deviceIp: _connectedIp,
      );
    }
    _connectedIp = null;
    _connectedPort = null;
    _useRoot = false;
    notifyListeners();
  }

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
      // Root mode aktif ise doğrudan komut çalıştır
      // (adb root komutu ile daemon root olarak başlatıldı)
      final actualCommand = command;

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
        details: 'Komut çalıştırıldı',
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

  Future<CommandResult> installAPK(String apkPath) async {
    if (!isConnected) {
      return CommandResult(
          success: false,
          command: 'install',
          output: '',
          error: 'Cihaz bağlı değil');
    }

    try {
      final result = await Process.run(
        'adb',
        ['-s', '$_connectedIp:$_connectedPort', 'install', '-r', '-g', apkPath],
      ).timeout(const Duration(minutes: 5));

      final success = result.exitCode == 0;
      final output = result.stdout.toString() + result.stderr.toString();

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
          success: false, command: 'install', output: '', error: e.toString());
    }
  }

  Future<bool> grantPermission(String packageName, String permission) async {
    final result = await executeCommand('pm grant $packageName $permission');

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