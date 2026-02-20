import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/adb/adb_client.dart';
import '../../../core/constants/app_constants.dart';

class EmergencyRecoveryScreen extends StatefulWidget {
  final ADBClient adbClient;

  const EmergencyRecoveryScreen({super.key, required this.adbClient});

  @override
  State<EmergencyRecoveryScreen> createState() =>
      _EmergencyRecoveryScreenState();
}

class _EmergencyRecoveryScreenState extends State<EmergencyRecoveryScreen> {
  bool _isExecuting = false;

  void _showToast(String msg, {bool isError = false, bool isSuccess = false}) {
    Fluttertoast.showToast(
      msg: msg,
      backgroundColor: isError
          ? AppConstants.errorRed
          : isSuccess
              ? AppConstants.successGreen
              : AppConstants.infoBlue,
      toastLength: Toast.LENGTH_LONG,
    );
  }

  Future<bool> _confirm(String title, String body) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('⚠️ $title'),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryRed),
            child: const Text('Evet, Çalıştır'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runCommand(String command) async {
    setState(() => _isExecuting = true);
    final result = await widget.adbClient.executeCommand(command);
    if (mounted) {
      setState(() => _isExecuting = false);
      if (result.success) {
        _showToast('✓ Komut başarıyla çalıştırıldı', isSuccess: true);
      } else {
        _showToast('✗ Hata: ${result.error}', isError: true);
      }
    }
  }

  bool _checkConnected() {
    if (!widget.adbClient.isConnected) {
      _showToast('Önce bir cihaza bağlanın!', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _runGoldenCommand() async {
    if (!_checkConnected()) return;
    final ok = await _confirm('Altın Komut',
        'CarWebGuru launcher\'ını zorla başlatacak.\nEmin misiniz?');
    if (!ok) return;
    await _runCommand(AppConstants.goldenCommand);
  }

  Future<void> _runSetDefaultLauncher() async {
    if (!_checkConnected()) return;
    final ok = await _confirm('Varsayılan Launcher',
        'CarWebGuru\'yu kalıcı launcher yapacak.\nEmin misiniz?');
    if (!ok) return;
    await _runCommand(AppConstants.setDefaultLauncher);
  }

  Future<void> _runKillResolver() async {
    if (!_checkConnected()) return;
    final ok = await _confirm('Menü Seçiciyi Kapat',
        'Donmuş launcher seçim penceresini kapatacak.\nEmin misiniz?');
    if (!ok) return;
    await _runCommand(AppConstants.killResolver);
  }

  Future<void> _listAllLaunchers() async {
    if (!_checkConnected()) return;

    setState(() => _isExecuting = true);
    final result = await widget.adbClient.executeCommand(
      'pm query-activities -a android.intent.action.MAIN -c android.intent.category.HOME',
    );
    if (!mounted) return;
    setState(() => _isExecuting = false);

    if (result.success) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sistemdeki Launcher\'lar'),
          content: SingleChildScrollView(
            child: SelectableText(
              result.output.isEmpty ? '(Sonuç boş)' : result.output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } else {
      _showToast('Hata: ${result.error}', isError: true);
    }
  }

  Future<void> _resetLauncherPreference() async {
    if (!_checkConnected()) return;

    final ok = await _confirm(
      'Launcher Sıfırlama',
      'Varsayılan launcher tercihini sıfırlayacak ve Altın Komutu çalıştıracak.\n\nDevam edilsin mi?',
    );
    if (!ok) return;

    setState(() => _isExecuting = true);

    await widget.adbClient.executeCommand(
      'pm clear-package-preferred-activities com.android.launcher3',
    );
    await Future.delayed(const Duration(milliseconds: 500));
    await widget.adbClient.executeCommand(AppConstants.goldenCommand);

    if (mounted) {
      setState(() => _isExecuting = false);
      _showToast('✓ Launcher sıfırlandı ve CarWebGuru başlatıldı',
          isSuccess: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, size: 28),
            SizedBox(width: 12),
            Text('ACİL KURTARMA'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.primaryRed,
              AppConstants.primaryRedLight.withAlpha(178),
              AppConstants.backgroundDark,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.yellow[700],
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, size: 32, color: Colors.black),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '🚨 ACİL LAUNCHER FİX ARACI\n\n'
                        'Bu araçlar sistem ayarlarını değiştirir. Sadece gerektiğinde kullanın.',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildEmergencyButton(
              title: '1. ALTIN KOMUT',
              subtitle: 'CarWebGuru launcher\'ını zorla başlat',
              description:
                  'Araç ekranı başka bir uygulamada kilitlendiğinde kullanın',
              icon: Icons.stars,
              onPressed: _runGoldenCommand,
            ),
            const SizedBox(height: 16),
            _buildEmergencyButton(
              title: '2. VARSAYILAN YAP',
              subtitle: 'CarWebGuru\'yu kalıcı launcher yap',
              description:
                  'Her açılışta "Hangi uygulama?" sorusu çıkıyorsa kullanın',
              icon: Icons.home,
              onPressed: _runSetDefaultLauncher,
            ),
            const SizedBox(height: 16),
            _buildEmergencyButton(
              title: '3. MENÜ SEÇİCİYİ KAPAT',
              subtitle: 'Donmuş launcher seçim penceresini kapat',
              description: 'Launcher seçim ekranı donmuşsa kullanın',
              icon: Icons.close_fullscreen,
              onPressed: _runKillResolver,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'GELİŞMİŞ ARAÇLAR',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isExecuting ? null : _listAllLaunchers,
              icon: const Icon(Icons.list),
              label: const Text('Tüm Launcher\'ları Listele'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isExecuting ? null : _resetLauncherPreference,
              icon: const Icon(Icons.refresh),
              label: const Text('Launcher Önceliğini Sıfırla'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyButton({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 8,
      child: InkWell(
        onTap: _isExecuting ? null : onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[400])),
                      ],
                    ),
                  ),
                  if (_isExecuting)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(description,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[300])),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
