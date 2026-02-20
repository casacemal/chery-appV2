import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/adb/adb_client.dart';
import '../../../core/constants/app_constants.dart';

class EmergencyRecoveryScreen extends StatefulWidget {
  final ADBClient adbClient;

  const EmergencyRecoveryScreen({super.key, required this.adbClient});

  @override
  State<EmergencyRecoveryScreen> createState() => _EmergencyRecoveryScreenState();
}

class _EmergencyRecoveryScreenState extends State<EmergencyRecoveryScreen> {
  bool _isExecuting = false;

  Future<void> _executeEmergencyCommand(
    String title,
    String command,
    {bool requiresConfirmation = true}
  ) async {
    if (!widget.adbClient.isConnected) {
      Fluttertoast.showToast(
        msg: 'Önce bir cihaza bağlanın!',
        backgroundColor: AppConstants.errorRed,
      );
      return;
    }

    if (requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('⚠️ $title'),
          content: const Text(
            'Bu kritik bir işlemdir. Launcher ayarlarını değiştirecek.\n\nEmin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryRed,
              ),
              child: const Text('Evet, Çalıştır'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isExecuting = true);

    final result = await widget.adbClient.executeCommand(command);

    setState(() => _isExecuting = false);

    Fluttertoast.showToast(
      msg: result.success ? '✓ Komut başarıyla çalıştırıldı' : '✗ Hata: ${result.error}',
      backgroundColor: result.success ? AppConstants.successGreen : AppConstants.errorRed,
      toastLength: Toast.LENGTH_LONG,
    );
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
              AppConstants.primaryRedLight.withAlpha(178), // withOpacity(0.7)
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
                        '🚨 ACİL LAUNCHER FİX ARACI\n\nBu araçlar sistem ayarlarını değiştirir. Sadece gerektiğinde kullanın.',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
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
              description: 'Araç ekranı başka bir uygulamada kilitlendiğinde kullanın',
              icon: Icons.stars,
              onPressed: () => _executeEmergencyCommand(
                'Altın Komut',
                AppConstants.goldenCommand,
              ),
            ),

            const SizedBox(height: 16),

            _buildEmergencyButton(
              title: '2. VARSAYILAN YAP',
              subtitle: 'CarWebGuru\'yu kalıcı launcher yap',
              description: 'Her açılışta "Hangi uygulama?" sorusu çıkıyorsa kullanın',
              icon: Icons.home,
              onPressed: () => _executeEmergencyCommand(
                'Varsayılan Launcher',
                AppConstants.setDefaultLauncher,
              ),
            ),

            const SizedBox(height: 16),

            _buildEmergencyButton(
              title: '3. MENÜ SEÇİCİYİ KAPAT',
              subtitle: 'Donmuş launcher seçim penceresini kapat',
              description: 'Launcher seçim ekranı donmuşsa kullanın',
              icon: Icons.close_fullscreen,
              onPressed: () => _executeEmergencyCommand(
                'Menü Seçiciyi Kapat',
                AppConstants.killResolver,
              ),
            ),

            const SizedBox(height: 32),

            const Divider(),

            const SizedBox(height: 16),

            const Text(
              'GELİŞMİŞ ARAÇLAR',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
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
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isExecuting)
                    const CircularProgressIndicator()
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
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _listAllLaunchers() async {
    setState(() => _isExecuting = true);

    final result = await widget.adbClient.executeCommand(
      'pm query-activities -a android.intent.action.MAIN -c android.intent.category.HOME',
    );

    setState(() => _isExecuting = false);

    if (result.success) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sistemdeki Launcher\'lar'),
            content: SingleChildScrollView(
              child: Text(result.output),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: 'Hata: ${result.error}',
        backgroundColor: AppConstants.errorRed,
      );
    }
  }

  Future<void> _resetLauncherPreference() async {
    if (mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Launcher Sıfırlama'),
          content: const Text(
            'Bu işlem varsayılan launcher tercihini sıfırlayacak ve ardından Altın Komutu çalıştıracak.\n\nDevam edilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Evet'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() => _isExecuting = true);

      await widget.adbClient.executeCommand('pm clear-package-preferred-activities com.android.launcher3');
      await Future.delayed(const Duration(milliseconds: 500));
      await widget.adbClient.executeCommand(AppConstants.goldenCommand);

      setState(() => _isExecuting = false);

      Fluttertoast.showToast(
        msg: '✓ Launcher sıfırlandı ve CarWebGuru başlatıldı',
        backgroundColor: AppConstants.successGreen,
        toastLength: Toast.LENGTH_LONG,
      );
    } 
  }
}
