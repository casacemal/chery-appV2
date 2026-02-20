import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class BlackBoxLogger {
  static final BlackBoxLogger _instance = BlackBoxLogger._internal();
  factory BlackBoxLogger() => _instance;
  BlackBoxLogger._internal();

  File? _currentLogFile;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final DateFormat _fileNameFormat = DateFormat('yyyyMMdd');

  Future<File> _getLogFile() async {
    final today = _fileNameFormat.format(DateTime.now());

    // Mevcut dosya bugünün dosyasıysa tekrar oluşturma
    if (_currentLogFile != null && await _currentLogFile!.exists()) {
      final fileName = _currentLogFile!.uri.pathSegments.last;
      if (fileName.contains(today)) return _currentLogFile!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${directory.path}/logs');

    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    final fileName = '${AppConstants.logFilePrefix}$today.txt';
    _currentLogFile = File('${logsDir.path}/$fileName');
    return _currentLogFile!;
  }

  Future<void> log({
    required LogOperation operation,
    required String details,
    required LogStatus status,
    String? command,
    String? output,
    String? deviceIp,
  }) async {
    try {
      final file = await _getLogFile();
      final timestamp = _dateFormat.format(DateTime.now());

      final safeDetails = details.replaceAll('\n', ' ');
      final safeCommand = command?.replaceAll('\n', ' ') ?? '';
      final safeOutput =
          output != null ? base64Encode(utf8.encode(output)) : '';
      final deviceInfo = deviceIp ?? 'N/A';

      final logLine =
          '[$timestamp]|${operation.name}|${status.name}|$deviceInfo|$safeDetails|$safeCommand|$safeOutput\n';

      await file.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      debugPrint('Logger error: $e'); // ✅ print → debugPrint
    }
  }

  Future<List<LogEntry>> getAllLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) return [];

      final List<LogEntry> allLogs = [];
      final files = logsDir
          .listSync()
          .where((f) => f.path.endsWith('.txt'))
          .map((f) => File(f.path))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      for (final file in files) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          final entry = _parseLogLine(line);
          if (entry != null) allLogs.add(entry);
        }
      }

      return allLogs;
    } catch (e) {
      debugPrint('Error reading logs: $e'); // ✅ print → debugPrint
      return [];
    }
  }

  LogEntry? _parseLogLine(String line) {
    try {
      final parts = line.split('|');
      if (parts.length < 5) return null;

      final timestampStr = parts[0].replaceAll('[', '').replaceAll(']', '');
      final operation = parts[1];
      final status = parts[2];
      final deviceIp = parts[3] == 'N/A' ? null : parts[3];
      final details = parts[4];
      final command = parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null;
      String? output;

      if (parts.length > 6 && parts[6].isNotEmpty) {
        try {
          output = utf8.decode(base64Decode(parts[6]));
        } catch (_) {
          output = parts[6];
        }
      }

      return LogEntry(
        timestamp: _dateFormat.parse(timestampStr),
        operation: operation,
        status: status,
        deviceIp: deviceIp,
        details: details,
        command: command,
        output: output,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cleanup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) return;

      final files = logsDir
          .listSync()
          .where((f) => f.path.endsWith('.txt'))
          .map((f) => File(f.path))
          .toList();

      final cutoffDate = DateTime.now()
          .subtract(const Duration(days: AppConstants.logRetentionDays));

      for (final file in files) {
        final stat = await file.stat();
        if (stat.modified.isBefore(cutoffDate)) {
          final newPath = file.path.replaceAll('.txt', '_archived.txt');
          await file.rename(newPath);
        }
      }
    } catch (e) {
      debugPrint('Cleanup error: $e'); // ✅ print → debugPrint
    }
  }
}

class LogEntry {
  final DateTime timestamp;
  final String operation;
  final String details;
  final String status;
  final String? deviceIp;
  final String? command;
  final String? output;

  LogEntry({
    required this.timestamp,
    required this.operation,
    required this.details,
    required this.status,
    this.deviceIp,
    this.command,
    this.output,
  });

  @override
  String toString() {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
    final deviceInfo = deviceIp != null ? ' | Device: $deviceIp' : '';
    return '[$dateStr] | [$operation] | $details | [$status]$deviceInfo';
  }
}

enum LogOperation {
  command,
  apkInstall,
  permissionGrant,
  emergency,
  connection,
  disconnection,
  error,
  scan,
}

enum LogStatus {
  success,
  failed,
  warning,
}
