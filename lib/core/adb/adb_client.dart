import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../shared/models/models.dart';
import '../logger/black_box_logger.dart';
import '../security/command_validator.dart';

class ADBClient extends ChangeNotifier {
  static final ADBClient _instance = ADBClient._internal();
  factory ADBClient() => _instance;
  ADBClient._internal();

  String? _connectedIp;
  int? _connectedPort;
  bool _useRoot = false;

  // ─── Kalıcı su Oturumu ───────────────────────────────────────────────────
  Process? _suProcess;
  StreamSubscription? _suStdoutSub;
  StreamSubscription? _suStderrSub;
  final _suOutputBuffer = StringBuffer();
  final _suErrorBuffer = StringBuffer();

  final _logger = BlackBoxLogger();
  final _rateLimiter = RateLimiter();

  bool get isConnected => _connectedIp != null;
  String? get connectedDevice => _connectedIp;
  bool get useRoot => _useRoot;

  // ─── ADB Binary Yönetimi ─────────────────────────────────────────────────

  static String? _adbBinaryPath;

  static Future<String> _getAdbPath() async {
    if (_adbBinaryPath != null) return _adbBinaryPath!;

    final dir = await getApplicationSupportDirectory();
    final adbFile = File('${dir.path}/adb');

    if (!adbFile.existsSync()) {
      // assets/adb dosyasını uygulama dizinine kopyala
      final data = await rootBundle.load('assets/adb');
      await adbFile.writeAsBytes(data.buffer.asUint8List());

      // Çalıştırma izni ver (chmod 755)
      final chmod = await Process.run('chmod', ['755', adbFile.path]);
      debugPrint('chmod result: ${chmod.exitCode} ${chmod.stderr}');
    }

    _adbBinaryPath = adbFile.path;
    debugPrint('ADB binary path: $_adbBinaryPath');
    return _adbBinaryPath!;
  }

  // ─── Root Yönetimi ───────────────────────────────────────────────────────

  Future<bool> enableRoot() async {
    if (!isConnected) return false;

    try {
      final adbPath = await _getAdbPath();

      // Önce adb root ile daemon root dene
      final result = await Process.run(
        adbPath,
        ['-s', '$_connectedIp:$_connectedPort', 'root'],
      ).timeout(const Duration(seconds: 10));

      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();

      final isSuccess = result.exitCode == 0 &&
          !stdout.contains('cannot') &&
          !stdout.contains('Production builds') &&
          !stderr.contains('cannot') &&
          !stderr.contains('Production builds');

      if (isSuccess) {
        if (stdout.contains('restarting')) {
          await Future.delayed(const Duration(seconds: 2));
        }
        _useRoot = true;
        notifyListeners();
        await _logger.log(
          operation: LogOperation.connection,
          details: 'Root mode etkinleştirildi (adb root): $stdout',
          status: LogStatus.success,
          deviceIp: _connectedIp,
        );
        return true;
      }

      // adb root başarısız → kalıcı su oturumu aç
      final suOk = await _startSuSession();
      if (suOk) {
        _useRoot = true;
        notifyListeners();
        await _logger.log(
          operation: LogOperation.connection,
          details: 'Root mode su oturumu üzerinden etkinleştirildi',
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

  // ─── Kalıcı su Oturumu Başlat ─────────────────────────────────────────────

  Future<bool> _startSuSession() async {
    try {
      await _closeSuSession(); // Varsa eskiyi kapat

      final adbPath = await _getAdbPath();

      _suProcess = await Process.start(
        adbPath,
        ['-s', '$_connectedIp:$_connectedPort', 'shell', 'su'],
      );

      // stdout/stderr dinle
      _suStdoutSub = _suProcess!.stdout
          .transform(utf8.decoder)
          .listen((data) => _suOutputBuffer.write(data));

      _suStderrSub = _suProcess!.stderr
          .transform(utf8.decoder)
          .listen((data) => _suErrorBuffer.write(data));

      // su oturumunun açıldığını test et
      await Future.delayed(const Duration(milliseconds: 500));

      final testResult = await _sendToSuSession('id');
      if (testResult.output.contains('uid=0')) {
        debugPrint('su oturumu başarıyla açıldı');
        return true;
      }

      await _closeSuSession();
      return false;
    } catch (e) {
      debugPrint('su oturumu hatası: $e');
      await _closeSuSession();
      return false;
    }
  }

  Future<void> _closeSuSession() async {
    try {
      _suProcess?.stdin.writeln('exit');
      await _suProcess?.stdin.close();
    } catch (_) {}
    await _suStdoutSub?.cancel();
    await _suStderrSub?.cancel();
    _suProcess?.kill();
    _suProcess = null;
    _suOutputBuffer.clear();
    _suErrorBuffer.clear();
  }

  // ─── su Oturumuna Komut Gönder ───────────────────────────────────────────

  Future<CommandResult> _sendToSuSession(String command) async {
    try {
      // Benzersiz marker ile komutun bitişini tespit et
      final marker = '___CMD_END_${DateTime.now().millisecondsSinceEpoch}___';

      _suOutputBuffer.clear();
      _suErrorBuffer.clear();

      _suProcess!.stdin.writeln(command);
      _suProcess!.stdin.writeln('echo "$marker"');

      // Marker görünene kadar bekle (max 15 saniye)
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
        final output = _suOutputBuffer.toString();
        if (output.contains(marker)) {
          // Marker'dan önceki kısmı al
          final cleanOutput = output
              .substring(0, output.indexOf(marker))
              .trim();
          return CommandResult(
            success: true,
            command: command,
            output: cleanOutput,
            error: null,
          );
        }
      }

      return CommandResult(
        success: false,
        command: command,
        output: _suOutputBuffer.toString(),
        error: 'Zaman aşımı',
      );
    } catch (e) {
      // Oturum koptu, sıfırla
      await _closeSuSession();
      _useRoot = false;
      notifyListeners();
      return CommandResult(
          success: false, command: command, output: '', error: 'su oturumu koptu: $e');
    }
  }

  void disableRoot() {
    _closeSuSession();
    _useRoot = false;
    notifyListeners();
  }

  // ─── Bağlantı ────────────────────────────────────────────────────────────

  Future<bool> connect(String ip, int port) async {
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
      // TCP port açık mı?
      final socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 5));
      await socket.close();

      final adbPath = await _getAdbPath();

      // Gerçek ADB bağlantısı
      final result = await Process.run(
        adbPath,
        ['connect', '$ip:$port'],
      ).timeout(const Duration(seconds: 10));

      final stdout = result.stdout.toString().trim();
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
      }

      await _logger.log(
        operation: LogOperation.connection,
        details: 'ADB bağlantısı reddedildi: $stdout',
        status: LogStatus.failed,
        deviceIp: ip,
      );
      return false;
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
    // su oturumunu kapat
    await _closeSuSession();

    if (_connectedIp != null) {
      try {
        final adbPath = await _getAdbPath();
        await Process.run(
          adbPath,
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
          success: false, command: command, output: '', error: 'Cihaz bağlı değil');
    }

    if (!_rateLimiter.canExecute()) {
      return CommandResult(
          success: false,
          command: command,
          output: '',
          error: 'Çok fazla istek. Lütfen bekleyin.');
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
          success: false, command: command, output: '', error: validation.error);
    }

    try {
      CommandResult result;

      if (_useRoot) {
        // su oturumu yoksa veya kopmuşsa yeniden aç
        if (_suProcess == null) {
          final ok = await _startSuSession();
          if (!ok) {
            return CommandResult(
                success: false,
                command: command,
                output: '',
                error: 'su oturumu açılamadı');
          }
        }
        result = await _sendToSuSession(command);
      } else {
        // Normal shell — adb shell komutu
        final adbPath = await _getAdbPath();
        final proc = await Process.run(
          adbPath,
          ['-s', '$_connectedIp:$_connectedPort', 'shell', command],
        ).timeout(const Duration(seconds: 15));

        final success = proc.exitCode == 0;
        final output = proc.stdout.toString();
        final error = proc.stderr.toString();

        result = CommandResult(
          success: success,
          command: command,
          output: output,
          error: error.isNotEmpty ? error : (success ? null : 'Bilinmeyen hata'),
        );
      }

      await _logger.log(
        operation: LogOperation.command,
        details: 'Komut çalıştırıldı${_useRoot ? " [ROOT]" : ""}',
        status: result.success ? LogStatus.success : LogStatus.failed,
        command: command,
        output: result.output,
        deviceIp: _connectedIp,
      );

      return result;
    } catch (e) {
      await _logger.log(
        operation: LogOperation.error,
        details: 'ADB Hatası: $e',
        status: LogStatus.failed,
        command: command,
        deviceIp: _connectedIp,
      );
      return CommandResult(
          success: false, command: command, output: '', error: e.toString());
    }
  }

  // ─── APK & İzin ──────────────────────────────────────────────────────────

  Future<CommandResult> installAPK(String apkPath) async {
    if (!isConnected) {
      return CommandResult(
          success: false, command: 'install', output: '', error: 'Cihaz bağlı değil');
    }

    try {
      final adbPath = await _getAdbPath();
      final result = await Process.run(
        adbPath,
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
