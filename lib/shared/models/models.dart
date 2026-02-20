class DeviceInfo {
  final String ipAddress;
  final int port;
  final DeviceStatus status;
  final String? modelName;
  final String? androidVersion;
  final DateTime? lastConnected;
  final bool isFavorite;

  DeviceInfo({
    required this.ipAddress,
    this.port = 5555,
    required this.status,
    this.modelName,
    this.androidVersion,
    this.lastConnected,
    this.isFavorite = false,
  });

  String get displayName {
    if (modelName != null) return '$modelName ($ipAddress)';
    return ipAddress;
  }

  DeviceInfo copyWith({
    String? ipAddress,
    int? port,
    DeviceStatus? status,
    String? modelName,
    String? androidVersion,
    DateTime? lastConnected,
    bool? isFavorite,
  }) {
    return DeviceInfo(
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      status: status ?? this.status,
      modelName: modelName ?? this.modelName,
      androidVersion: androidVersion ?? this.androidVersion,
      lastConnected: lastConnected ?? this.lastConnected,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ipAddress': ipAddress,
      'port': port,
      'status': status.name, // ✅ .name kullan, daha temiz parse
      'modelName': modelName,
      'androidVersion': androidVersion,
      'lastConnected': lastConnected?.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      ipAddress: json['ipAddress'] as String? ?? '0.0.0.0', // ✅ null-safe
      port: json['port'] as int? ?? 5555,
      status: DeviceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeviceStatus.offline,
      ),
      modelName: json['modelName'] as String?,
      androidVersion: json['androidVersion'] as String?,
      lastConnected: json['lastConnected'] != null
          ? DateTime.tryParse(json['lastConnected'] as String) // ✅ tryParse
          : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

enum DeviceStatus {
  ready,    // Port açık + ADB yanıt veriyor → YEŞİL
  portOpen, // Port açık ama ADB yanıt yok  → SARI
  offline,  // Port kapalı / ulaşılamıyor   → GRİ
}

class CommandResult {
  final bool success;
  final String output;
  final String? error;
  final String command;
  final DateTime timestamp;

  CommandResult({
    required this.success,
    required this.output,
    this.error,
    required this.command,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedOutput =>
      success ? output.trim() : (error?.trim() ?? 'Bilinmeyen hata');

  bool get hasOutput => output.trim().isNotEmpty;
  bool get hasError => error != null && error!.trim().isNotEmpty;
}

class AppPackage {
  final String packageName;
  final String? appName;
  final String? version;
  final DateTime? installDate;
  final bool isSystemApp;

  const AppPackage({
    required this.packageName,
    this.appName,
    this.version,
    this.installDate,
    this.isSystemApp = false,
  });

  String get displayName => appName ?? packageName;

  @override
  String toString() => displayName;
}
