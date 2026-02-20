import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'Chery Master Controller Pro';
  static const String appVersion = '1.3.0';

  // Network
  static const int adbDefaultPort = 5555;
  static const int networkScanTimeout = 2000;
  static const int commandTimeout = 10000;
  static const int maxReconnectAttempts = 3;

  // Theme Colors - Chery Brand
  static const Color primaryRed = Color(0xFFB71C1C);
  static const Color primaryRedLight = Color(0xFFD32F2F);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Status Colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFEF5350); // ✅ primaryRed'den farklı
  static const Color infoBlue = Color(0xFF2196F3);

  // CarWebGuru Launcher
  static const String carWebGuruPackage = 'com.softartstudio.carwebguru';
  static const String carWebGuruActivity = '.MainActivity';

  // Emergency Commands
  static const String goldenCommand =
      'am start -n $carWebGuruPackage/$carWebGuruActivity '
      '-a android.intent.action.MAIN -c android.intent.category.HOME '
      '-f 0x10000100';
  static const String setDefaultLauncher =
      'cmd package set-home-activity $carWebGuruPackage/$carWebGuruActivity';
  static const String killResolver =
      'am force-stop com.android.internal.app.ResolverActivity';

  // APK Permissions to grant
  static const List<String> criticalPermissions = [
    'android.permission.WRITE_EXTERNAL_STORAGE',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.RECORD_AUDIO',
    'android.permission.CAMERA',
    'android.permission.READ_PHONE_STATE',
  ];

  // Security - Whitelist: komutun ilk kelimesi bunlardan biri olmalı
  static const List<String> whitelistCommands = [
    'am',
    'pm',
    'input',
    'appops',
    'cmd',
    'settings',
    'dumpsys',
    'getprop',
    'setprop',
    'wm',
    'content',
    'screencap',
  ];

  // Security - Blacklist: tehlikeli pattern eşleşmesi
  // NOT: 'su' buradan kaldırıldı, CommandValidator içinde kelime bazlı kontrol ediliyor
  static const List<String> blacklistPatterns = [
    'rm -rf',
    'dd if=',
    'mount ',
    'format ',
    '/dev/block',
    'busybox',
    'chmod 777',
    '>/system/',
    '>/data/',
  ];

  // Pipe/chaining karakterleri — karakter bazlı kontrol
  static const List<String> dangerousChars = [';', '|', '&&', '||'];

  // Log Settings
  static const int maxLogFileSizeMB = 10;
  static const int logRetentionDays = 30;
  static const String logFilePrefix = 'chery_master_logs_';
}
