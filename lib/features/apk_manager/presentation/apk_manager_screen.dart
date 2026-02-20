import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/adb/adb_client.dart';
import '../../../core/constants/app_constants.dart';

class APKManagerScreen extends StatefulWidget {
  final ADBClient adbClient;

  const APKManagerScreen({super.key, required this.adbClient});

  @override
  State<APKManagerScreen> createState() => _APKManagerScreenState();
}

class _APKManagerScreenState extends State<APKManagerScreen> {
  String? _lastInstalledPackage;
  bool _isInstalling = false;

  Future<void> _pickAndInstallAPK() async {
    if (!widget.adbClient.isConnected) {
      Fluttertoast.showToast(
        msg: 'Önce bir cihaza bağlanın!',
        backgroundColor: AppConstants.errorRed,
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result == null || result.files.single.path == null) return;

    final apkPath = result.files.single.path!;

    setState(() => _isInstalling = true);

    Fluttertoast.showToast(
      msg: 'APK yükleniyor... Bu işlem birkaç dakika sürebilir',
      backgroundColor: AppConstants.infoBlue,
      toastLength: Toast.LENGTH_LONG,
    );

    final installResult = await widget.adbClient.installAPK(apkPath);

    setState(() => _isInstalling = false);

    if (installResult.success) {
      // Try to extract package name from output
      final packageName = _extractPackageName(installResult.output);
      setState(() => _lastInstalledPackage = packageName);

      Fluttertoast.showToast(
        msg: '✓ APK başarıyla yüklendi',
        backgroundColor: AppConstants.successGreen,
        toastLength: Toast.LENGTH_LONG,
      );
    } else {
      Fluttertoast.showToast(
        msg: '✗ Yükleme başarısız: ${installResult.error}',
        backgroundColor: AppConstants.errorRed,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  String? _extractPackageName(String output) {
    // Try to find package name from install output
    final regex = RegExp(r'package:([^\s]+)');
    final match = regex.firstMatch(output);
    return match?.group(1);
  }

  Future<void> _grantAllPermissions() async {
    if (_lastInstalledPackage == null) {
      Fluttertoast.showToast(
        msg: 'Önce bir APK yükleyin',
        backgroundColor: AppConstants.warningOrange,
      );
      return;
    }

    setState(() => _isInstalling = true);

    int granted = 0;
    int failed = 0;

    for (final permission in AppConstants.criticalPermissions) {
      final success = await widget.adbClient.grantPermission(
        _lastInstalledPackage!,
        permission,
      );

      if (success) {
        granted++;
      } else {
        failed++;
      }
    }

    // Grant SYSTEM_ALERT_WINDOW via appops
    await widget.adbClient.executeCommand(
      'appops set $_lastInstalledPackage SYSTEM_ALERT_WINDOW allow',
    );

    setState(() => _isInstalling = false);

    Fluttertoast.showToast(
      msg: '✓ $granted izin verildi, $failed başarısız',
      backgroundColor: AppConstants.successGreen,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.android, size: 28),
            SizedBox(width: 12),
            Text('APK YÖNETİMİ'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.upload_file,
                    size: 64,
                    color: AppConstants.primaryRed,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'APK YÜKLEME',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Telefonnuzdan APK dosyası seçip araca yükleyin',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isInstalling ? null : _pickAndInstallAPK,
                      icon: _isInstalling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.folder_open),
                      label: Text(
                        _isInstalling ? 'Yükleniyor...' : 'APK Dosyası Seç ve Yükle',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_lastInstalledPackage != null) ...[
            Card(
              color: AppConstants.surfaceDark,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppConstants.successGreen,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Son Yüklenen Paket',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.backgroundDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _lastInstalledPackage!,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isInstalling ? null : _grantAllPermissions,
                        icon: const Icon(Icons.security),
                        label: const Text('Tüm İzinleri Ver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.successGreen,
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Verilecek İzinler'),
              children: [
                ...AppConstants.criticalPermissions.map(
                  (perm) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.check, size: 16),
                    title: Text(
                      perm.split('.').last,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.check, size: 16),
                  title: Text(
                    'SYSTEM_ALERT_WINDOW',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
