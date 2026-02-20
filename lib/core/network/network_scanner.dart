import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../shared/models/models.dart';
import '../logger/black_box_logger.dart';
import '../constants/app_constants.dart';

class NetworkScanner {
  final _logger = BlackBoxLogger();
  final _networkInfo = NetworkInfo();

  Future<String?> getPhoneIP() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (e) {
      debugPrint('Error getting phone IP: $e'); // ✅ print → debugPrint
      return null;
    }
  }

  String? getSubnet(String ipAddress) {
    try {
      final parts = ipAddress.split('.');
      if (parts.length != 4) return null;
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    } catch (_) {
      return null;
    }
  }

  Future<List<DeviceInfo>> scanNetwork() async {
    await _logger.log(
      operation: LogOperation.scan,
      details: 'Network scan started',
      status: LogStatus.success,
    );

    final phoneIP = await getPhoneIP();
    if (phoneIP == null) {
      await _logger.log(
        operation: LogOperation.scan,
        details: 'Failed - No IP address',
        status: LogStatus.failed,
      );
      return [];
    }

    final subnet = getSubnet(phoneIP);
    if (subnet == null) return [];

    final List<DeviceInfo> devices = [];
    final futures = <Future>[];

    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';

      futures.add(_checkDevice(ip).then((device) {
        if (device != null) devices.add(device);
      }));

      // Batch işlem: sistemi yormamak için 50'şerli gruplar
      if (i % 50 == 0) {
        await Future.wait(futures);
        futures.clear();
      }
    }

    if (futures.isNotEmpty) await Future.wait(futures);

    await _logger.log(
      operation: LogOperation.scan,
      details: 'Scan completed - Found ${devices.length} device(s)',
      status: LogStatus.success,
    );

    return devices;
  }

  Future<DeviceInfo?> _checkDevice(String ip) async {
    try {
      bool port5555Open = false;
      try {
        final socket = await Socket.connect(
          ip,
          AppConstants.adbDefaultPort,
          timeout: const Duration(milliseconds: 500),
        );
        port5555Open = true;
        await socket.close();
      } catch (_) {
        // Port kapalı, normal durum
      }

      if (port5555Open) {
        final adbResponding = await _testADBConnection(ip);
        String? modelName;
        if (adbResponding) {
          modelName = await _getDeviceModel(ip);
        }
        return DeviceInfo(
          ipAddress: ip,
          port: AppConstants.adbDefaultPort,
          status: adbResponding ? DeviceStatus.ready : DeviceStatus.portOpen,
          modelName: modelName,
        );
      } else {
        if (await _isHostAlive(ip)) {
          return DeviceInfo(
            ipAddress: ip,
            port: 0,
            status: DeviceStatus.offline,
            modelName: await _getHostname(ip),
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isHostAlive(String ip) async {
    try {
      final result = await Process.run('ping', ['-c', '1', '-W', '1', ip]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _getHostname(String ip) async {
    try {
      final address = await InternetAddress(ip).reverse();
      return address.host != ip ? address.host : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getDeviceModel(String ip) async {
    try {
      final result = await Process.run(
        'adb',
        ['-s', '$ip:${AppConstants.adbDefaultPort}', 'shell', 'getprop ro.product.model'],
      ).timeout(const Duration(seconds: 2));

      if (result.exitCode == 0) {
        final model = result.stdout.toString().trim();
        return model.isNotEmpty ? model : null;
      }
    } catch (_) {
      // ADB model sorgusu başarısız, önemli değil
    }
    return null;
  }

  Future<bool> _testADBConnection(String ip) async {
    try {
      final result = await Process.run(
        'adb',
        ['connect', '$ip:${AppConstants.adbDefaultPort}'],
      ).timeout(const Duration(seconds: 2));

      return result.stdout.toString().contains('connected');
    } catch (_) {
      return false;
    }
  }

  Future<DeviceInfo?> quickCheck(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port,
          timeout: const Duration(seconds: 2));
      await socket.close();

      final adbResponding = await _testADBConnection(ip);
      return DeviceInfo(
        ipAddress: ip,
        port: port,
        status: adbResponding ? DeviceStatus.ready : DeviceStatus.portOpen,
      );
    } catch (_) {
      return DeviceInfo(
        ipAddress: ip,
        port: port,
        status: DeviceStatus.offline,
      );
    }
  }
}
