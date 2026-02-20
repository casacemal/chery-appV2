import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/network/network_scanner.dart';
import '../../../core/adb/adb_client.dart';
import '../../../shared/models/models.dart';
import '../../../core/constants/app_constants.dart';

class DeviceScannerScreen extends StatefulWidget {
  final NetworkScanner scanner;
  final ADBClient adbClient;

  const DeviceScannerScreen({
    super.key,
    required this.scanner,
    required this.adbClient,
  });

  @override
  State<DeviceScannerScreen> createState() => _DeviceScannerScreenState();
}

class _DeviceScannerScreenState extends State<DeviceScannerScreen> {
  List<DeviceInfo> _devices = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    final devices = await widget.scanner.scanNetwork();

    setState(() {
      _devices = devices;
      _isScanning = false;
    });

    Fluttertoast.showToast(
      msg: '${devices.length} cihaz bulundu',
      backgroundColor: AppConstants.infoBlue,
    );
  }

  Future<void> _connectToDevice(DeviceInfo device) async {
    final success =
        await widget.adbClient.connect(device.ipAddress, device.port);

    if (success) {
      Fluttertoast.showToast(
        msg: '✓ ${device.ipAddress} adresine bağlanıldı',
        backgroundColor: AppConstants.successGreen,
        toastLength: Toast.LENGTH_LONG,
      );

      if (mounted) Navigator.pop(context);
    } else {
      Fluttertoast.showToast(
        msg: '✗ Bağlantı başarısız',
        backgroundColor: AppConstants.errorRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort devices: ready first, then portOpen, then offline
    final sortedDevices = List<DeviceInfo>.from(_devices)
      ..sort((a, b) {
        if (a.status == b.status) return a.ipAddress.compareTo(b.ipAddress);
        if (a.status == DeviceStatus.ready) return -1;
        if (b.status == DeviceStatus.ready) return 1;
        if (a.status == DeviceStatus.portOpen) return -1;
        if (b.status == DeviceStatus.portOpen) return 1;
        return 0;
      });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar, size: 28),
            SizedBox(width: 12),
            Text('CİHAZ TARAMA'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _isScanning ? null : _startScan,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yeniden Tara',
          ),
        ],
      ),
      body: _isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SpinKitRipple(
                    color: AppConstants.primaryRed,
                    size: 100,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ağ taranıyor...',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu işlem 5-10 saniye sürebilir',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            )
          : sortedDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 80,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cihaz bulunamadı',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Araç multimedya sisteminde ADB\'nin\naktif olduğundan emin olun',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _startScan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tekrar Tara'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDevices.length,
                  itemBuilder: (context, index) {
                    final device = sortedDevices[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDeviceCard(device),
                    );
                  },
                ),
    );
  }

  Widget _buildDeviceCard(DeviceInfo device) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    double opacity = 1.0;

    switch (device.status) {
      case DeviceStatus.ready:
        statusColor = AppConstants.successGreen;
        statusText = 'HAZIR';
        statusIcon = Icons.check_circle;
        break;
      case DeviceStatus.portOpen:
        statusColor = AppConstants.warningOrange;
        statusText = 'PORT AÇIK';
        statusIcon = Icons.warning;
        break;
      case DeviceStatus.offline:
        statusColor = Colors.grey;
        statusText = 'DİĞER CİHAZ';
        statusIcon = Icons.devices_other;
        opacity = 0.5; // Faded as requested
        break;
      default:
        statusColor = AppConstants.errorRed;
        statusText = 'BİLİNMİYOR';
        statusIcon = Icons.help_outline;
        opacity = 0.5;
    }

    final bool isConnectable = device.status == DeviceStatus.ready ||
        device.status == DeviceStatus.portOpen;

    return Opacity(
      opacity: opacity,
      child: Card(
        elevation: device.status == DeviceStatus.ready ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: device.status == DeviceStatus.ready
              ? BorderSide(color: statusColor, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isConnectable ? () => _connectToDevice(device) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25), // withOpacity(0.1)
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.modelName ?? device.ipAddress,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: device.modelName != null
                              ? Colors.white
                              : Colors.white70,
                        ),
                      ),
                      if (device.modelName != null)
                        Text(
                          device.ipAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(51), // withOpacity(0.2)
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: statusColor.withAlpha(128)), // withOpacity(0.5)
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (device.port > 0)
                            Text(
                              'Port: ${device.port}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isConnectable)
                  Icon(
                    Icons.chevron_right,
                    color: statusColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
