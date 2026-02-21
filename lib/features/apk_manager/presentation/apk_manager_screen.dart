import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart'; // Provider paketini ekledik
import '../../../core/adb/adb_client.dart';
import '../../../core/constants/app_constants.dart';

class APKManagerScreen extends StatefulWidget {
  // adbClient parametresini constructor'dan kaldırdık
  const APKManagerScreen({super.key});

  @override
  State<APKManagerScreen> createState() => _APKManagerScreenState();
}

class _APKManagerScreenState extends State<APKManagerScreen> {
  String? _lastInstalledPackage;
  bool _isInstalling = false;
  final TextEditingController _packageController = TextEditingController();

  @override
  void dispose() {
    _packageController.dispose();
    super.dispose();
  }

  Future<void> _pickAndInstallAPK() async {
    // Asenkron işlemlerden önce adbClient'ı context üzerinden alıyoruz
    final adbClient = context.read<ADBClient>();

    if (!adbClient.isConnected) {
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

    // Kurulum öncesi paket listesi
    final packagesBefore = await adbClient.getInstalledPackages();

    setState(() => _isInstalling = true);

    Fluttertoast.showToast(
      msg: 'APK yükleniyor... Bu işlem birkaç dakika sürebilir',
      backgroundColor: AppConstants.infoBlue,
      toastLength: Toast.LENGTH_LONG,
    );

    final installResult = await adbClient.installAPK(apkPath);

    if (installResult.success) {
      // Kurulum sonrası paket listesi → fark = yeni paket
      final packagesAfter = await adbClient.getInstalledPackages();
      final newPackages = packagesAfter
          .where((p) => !packagesBefore.contains(p))
          .toList();

      String? detectedPackage;
      if (newPackages.length == 1) {
        detectedPackage = newPackages.first;
      }

      if (mounted) {
        setState(() {
          _isInstalling = false;
          _lastInstalledPackage = detectedPackage;
        });
      }

      if (detectedPackage != null) {
        Fluttertoast.showToast(
          msg: '✓ APK başarıyla yüklendi: $detectedPackage',
          backgroundColor: AppConstants.successGreen,
          toastLength: Toast.LENGTH_LONG,
        );
      } else {
        // Otomatik tespit başarısız → kullanıcıdan manuel giriş iste
        Fluttertoast.showToast(
          msg: '✓ APK yüklendi. Paket adını manuel girin.',
          backgroundColor: AppConstants.warningOrange,
          toastLength: Toast.LENGTH_LONG,
        );
        await _askPackageName(apkPath);
      }
    } else {
      if (mounted) setState(() => _isInstalling = false);
      Fluttertoast.showToast(
        msg: '✗ Yükleme başarısız: ${installResult.error}',
        backgroundColor: AppConstants.errorRed,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  /// Otomatik tespit başarısız olursa kullanıcıdan paket adı ister
  Future<void> _askPackageName(String apkPath) async {
    // APK dosya adından tahmin yürüt (örn: "com.example.app-1.0.apk" → "com.example.app")
    final fileName = apkPath.split('/').last.replaceAll('.apk', '');
    _packageController.text = fileName.contains('.') ? fileName : '';

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Paket Adı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paket adı otomatik tespit edilemedi.\n'
              'İzin vermek için paket adını girin:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _packageController,
              decoration: const InputDecoration(
                labelText: 'Paket Adı',
                hintText: 'com.example.app',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Atla'),
          ),
          ElevatedButton(
            onPressed: () {
              final pkg = _packageController.text.trim();
              if (pkg.isNotEmpty) {
                setState(() => _lastInstalledPackage = pkg);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
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

    // Asenkron işlemlerden önce adbClient'ı context üzerinden alıyoruz
    final adbClient = context.read<ADBClient>();

    int granted = 0;
    int failed = 0;

    for (final permission in AppConstants.criticalPermissions) {
      final success = await adbClient.grantPermission(
        _lastInstalledPackage!,
        permission,
      );
      if (success) granted++; else failed++;
    }

    // SYSTEM_ALERT_WINDOW via appops
    await adbClient.executeCommand(
      'appops set $_lastInstalledPackage SYSTEM_ALERT_WINDOW allow',
    );

    if (mounted) setState(() => _isInstalling = false);

    Fluttertoast.showToast(
      msg: '✓ $granted izin verildi${failed > 0 ? ', $failed başarısız' : ''}',
      backgroundColor:
          failed == 0 ? AppConstants.successGreen : AppConstants.warningOrange,
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
                  const Icon(Icons.upload_file,
                      size: 64, color: AppConstants.primaryRed),
                  const SizedBox(height: 16),
                  const Text(
                    'APK YÜKLEME',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Telefonunuzdan APK dosyası seçip araca yükleyin',
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
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.folder_open),
                      label: Text(_isInstalling
                          ? 'Yükleniyor...'
                          : 'APK Dosyası Seç ve Yükle'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(20)),
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
                        Icon(Icons.check_circle,
                            color: AppConstants.successGreen),
                        SizedBox(width: 12),
                        Text(
                          'Son Yüklenen Paket',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
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
                        onPressed:
                            _isInstalling ? null : _grantAllPermissions,
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
                    title: Text(perm.split('.').last,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const ListTile(
                  dense: true,
                  leading: Icon(Icons.check, size: 16),
                  title: Text('SYSTEM_ALERT_WINDOW',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
