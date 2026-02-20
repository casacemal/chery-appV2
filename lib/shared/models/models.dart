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
      'status': status.toString(),
      'modelName': modelName,
      'androidVersion': androidVersion,
      'lastConnected': lastConnected?.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      ipAddress: json['ipAddress'],
      port: json['port'] ?? 5555,
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DeviceStatus.offline,
      ),
      modelName: json['modelName'],
      androidVersion: json['androidVersion'],
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'])
          : null,
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

enum DeviceStatus {
  ready, // Port open + ADB responding (GREEN)
  portOpen, // Port open but no ADB response (YELLOW)
  offline, // Port closed (RED)
  connecting, // Currently connecting
  connected, // Successfully connected
}

class CommandResult {
  final bool success;
  final String output;
  final String? error;
  final DateTime timestamp;
  final String command;

  CommandResult({
    required this.success,
    required this.output,
    this.error,
    required this.command,
  }) : timestamp = DateTime.now();

  String get formattedOutput {
    if (success) return output;
    return error ?? 'Unknown error';
  }
}

class AppPackage {
  final String packageName;
  final String? appName;
  final String? version;
  final DateTime? installDate;
  final bool isSystemApp;

  AppPackage({
    required this.packageName,
    this.appName,
    this.version,
    this.installDate,
    this.isSystemApp = false,
  });

  String get displayName => appName ?? packageName;
}
