import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../../core/network/network_scanner.dart';
import '../../../core/adb/adb_client.dart';
import '../../../shared/models/models.dart';
import '../../../core/constants/app_constants.dart';

class DeviceScannerScreen extends StatefulWidget {
  final NetworkScanner scanner;

  const DeviceScannerScreen({super.key, required this.scanner});

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

  // ─── Tarama ─────────────────────────────────────────────────────────────

  Future<void> _startScan() async {
    final adbClient = context.read<ADBClient>();

    // Taramadan önce mevcut bağlantıyı kes
    if (adbClient.isConnected) {
      await adbClient.disconnect();
      Fluttertoast.showToast(
        msg: 'Mevcut bağlantı kesildi, tarama başlıyor...',
        backgroundColor: AppConstants.warningOrange,
      );
    }

    setState(() {
      _isScanning = true;
      _devices = [];
    });

    final devices = await widget.scanner.scanNetwork();

    if (mounted) {
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
      Fluttertoast.showToast(
        msg: '${devices.length} cihaz bulundu',
        backgroundColor: AppConstants.infoBlue,
      );
    }
  }

  // ─── Bağlantı / Bağlantı Kes ────────────────────────────────────────────

  Future<void> _connectToDevice(DeviceInfo device) async {
    final adbClient = context.read<ADBClient>();

    // Yükleme göstergesi
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppConstants.primaryRed),
        ),
      );
    }

    final success = await adbClient.connect(device.ipAddress, device.port);

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (success) {
      Fluttertoast.showToast(
        msg: '✓ ${device.ipAddress} adresine bağlanıldı',
        backgroundColor: AppConstants.successGreen,
        toastLength: Toast.LENGTH_LONG,
      );
      if (mounted) Navigator.pop(context);
    } else {
      final errorDetail =
          adbClient.lastConnectionError ?? 'Bilinmeyen bir hata oluştu.';
      if (mounted) _showErrorDialog(device, errorDetail);
    }
  }

  Future<void> _disconnect() async {
    final adbClient = context.read<ADBClient>();
    await adbClient.disconnect();
    Fluttertoast.showToast(
      msg: 'Bağlantı kesildi',
      backgroundColor: AppConstants.warningOrange,
    );
  }

  // ─── Bağlantı Hatası Diyaloğu ────────────────────────────────────────────

  void _showErrorDialog(DeviceInfo device, String errorDetail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppConstants.errorRed, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: AppConstants.errorRed, size: 26),
            SizedBox(width: 10),
            Text('Bağlantı Başarısız',
                style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IP bilgisi
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.router, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('${device.ipAddress}:${device.port}',
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white70)),
              ]),
            ),
            const SizedBox(height: 14),
            // Hata satırları
            ...errorDetail.split('\n').map((line) {
              final isBullet = line.trim().startsWith('•');
              return Padding(
                padding:
                    EdgeInsets.only(bottom: 4, left: isBullet ? 4 : 0),
                child: Text(line,
                    style: TextStyle(
                      fontSize: isBullet ? 12.5 : 13.5,
                      color: isBullet ? Colors.white60 : Colors.white,
                      fontWeight: isBullet
                          ? FontWeight.normal
                          : FontWeight.w500,
                      height: 1.4,
                    )),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('TAMAM', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Tekrar Dene'),
            onPressed: () {
              Navigator.pop(ctx);
              _connectToDevice(device);
            },
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final adbClient = context.watch<ADBClient>();

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
        title: const Row(children: [
          Icon(Icons.radar, size: 28),
          SizedBox(width: 12),
          Text('CİHAZ TARAMA'),
        ]),
        actions: [
          // Bağlantı kes (sadece bağlıyken)
          if (adbClient.isConnected)
            IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Bağlantıyı Kes',
              onPressed: _disconnect,
            ),
          IconButton(
            onPressed: _isScanning ? null : _startScan,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yeniden Tara',
          ),
        ],
      ),
      body: Column(
        children: [
          // Bağlı cihaz bandı
          if (adbClient.isConnected)
            _buildConnectionBanner(adbClient.connectedDevice!),

          Expanded(
            child: _isScanning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SpinKitRipple(
                            color: AppConstants.primaryRed, size: 100),
                        const SizedBox(height: 24),
                        const Text('Ağ taranıyor...',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Bu işlem 5-10 saniye sürebilir',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[400])),
                      ],
                    ),
                  )
                : sortedDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off,
                                size: 80, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            const Text('Cihaz bulunamadı',
                                style: TextStyle(fontSize: 18)),
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
                            child: _buildDeviceCard(
                                device, adbClient.connectedDevice),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner(String ip) {
    return Container(
      width: double.infinity,
      color: AppConstants.successGreen.withAlpha(30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Icon(Icons.link, color: AppConstants.successGreen, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Bağlı: $ip',
              style: const TextStyle(
                  color: AppConstants.successGreen,
                  fontWeight: FontWeight.bold)),
        ),
        TextButton.icon(
          onPressed: _disconnect,
          icon: const Icon(Icons.link_off,
              size: 16, color: AppConstants.errorRed),
          label: const Text('Bağlantıyı Kes',
              style: TextStyle(
                  color: AppConstants.errorRed, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _buildDeviceCard(DeviceInfo device, String? connectedIp) {
    final isCurrentlyConnected = device.ipAddress == connectedIp;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    double opacity = 1.0;

    if (isCurrentlyConnected) {
      statusColor = AppConstants.successGreen;
      statusText = 'BAĞLI';
      statusIcon = Icons.link;
    } else {
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
          opacity = 0.5;
          break;
        default:
          statusColor = AppConstants.errorRed;
          statusText = 'BİLİNMİYOR';
          statusIcon = Icons.help_outline;
          opacity = 0.5;
      }
    }

    final bool isConnectable = !isCurrentlyConnected &&
        (device.status == DeviceStatus.ready ||
            device.status == DeviceStatus.portOpen);

    return Opacity(
      opacity: opacity,
      child: Card(
        elevation:
            isCurrentlyConnected || device.status == DeviceStatus.ready
                ? 8
                : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isCurrentlyConnected || device.status == DeviceStatus.ready
              ? BorderSide(color: statusColor, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isConnectable ? () => _connectToDevice(device) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
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
                      Text(device.ipAddress,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 8),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(51),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: statusColor.withAlpha(128)),
                        ),
                        child: Text(statusText,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor)),
                      ),
                      const SizedBox(width: 8),
                      if (device.port > 0)
                        Text('Port: ${device.port}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                    ]),
                  ],
                ),
              ),
              // Bağlıysa kes ikonu, bağlanabilirse ok
              if (isCurrentlyConnected)
                IconButton(
                  icon: const Icon(Icons.link_off,
                      color: AppConstants.errorRed),
                  tooltip: 'Bağlantıyı Kes',
                  onPressed: _disconnect,
                )
              else if (isConnectable)
                Icon(Icons.chevron_right, color: statusColor),
            ]),
          ),
        ),
      ),
    );
  }
}
