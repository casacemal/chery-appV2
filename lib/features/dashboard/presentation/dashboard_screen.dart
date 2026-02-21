import 'package:flutter/material.dart';
import '../../../core/network/network_scanner.dart';
import '../../../core/adb/adb_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../device_scanner/presentation/device_scanner_screen.dart';
import '../../emergency_recovery/presentation/emergency_recovery_screen.dart';
import '../../apk_manager/presentation/apk_manager_screen.dart';
import '../../command_panel/presentation/command_panel_screen.dart';
import '../../log_viewer/presentation/log_viewer_screen.dart';
import '../../ai_settings/presentation/ai_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scanner = NetworkScanner();
  final _adbClient = ADBClient();
  String? _phoneIP;

  @override
  void initState() {
    super.initState();
    _loadPhoneIP();
  }

  Future<void> _loadPhoneIP() async {
    final ip = await _scanner.getPhoneIP();
    if (mounted) setState(() => _phoneIP = ip);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _adbClient,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Row(
              children: [
                Icon(Icons.directions_car, size: 28),
                SizedBox(width: 12),
                Text(AppConstants.appName),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                padding: const EdgeInsets.all(12),
                color: AppConstants.surfaceDark,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_android,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'TEL: ${_phoneIP ?? "..."}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _adbClient.isConnected
                                ? AppConstants.successGreen
                                : AppConstants.errorRed,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _adbClient.isConnected
                              ? 'BAĞLI: ${_adbClient.connectedDevice}'
                              : 'BAĞLANTI YOK',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _adbClient.isConnected
                                ? AppConstants.successGreen
                                : AppConstants.errorRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Ana Kartlar (2x2) ──────────────────────────────────────
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _buildFeatureCard(
                        title: 'CİHAZ TARAMA',
                        subtitle: 'Araçları bul',
                        icon: Icons.radar,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceScannerScreen(
                              scanner: _scanner,
                              adbClient: _adbClient,
                            ),
                          ),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'KOMUT PANELİ',
                        subtitle: 'Kontrol & Butonlar',
                        icon: Icons.gamepad,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF57C00), Color(0xFFFF9800)],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CommandPanelScreen(adbClient: _adbClient),
                          ),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'APK YÖNETİMİ',
                        subtitle: 'Uygulama yükle',
                        icon: Icons.android,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF388E3C), Color(0xFF4CAF50)],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                APKManagerScreen(adbClient: _adbClient),
                          ),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'SİSTEM GÜNLÜKLERİ',
                        subtitle: 'Log & Çıktılar',
                        icon: Icons.terminal,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF607D8B), Color(0xFF455A64)],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LogViewerScreen(),
                          ),
                        ),
                      ),
                      _buildFeatureCard(
                        title: 'ACİL KURTARMA',
                        subtitle: 'Launcher düzelt',
                        icon: Icons.warning_amber,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EmergencyRecoveryScreen(adbClient: _adbClient),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── AI Ayarları Küçük Kart ─────────────────────────────────
                _buildAICard(),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── AI Küçük Kart ──────────────────────────────────────────────────────────
  Widget _buildAICard() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AISettingsScreen()),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.white, size: 26),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI ASISTAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Groq API ayarları & prompt',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withAlpha(230),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
