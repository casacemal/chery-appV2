import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/adb/adb_client.dart';
import '../../../core/security/command_validator.dart';
import '../../../core/constants/key_codes.dart';
import '../../../core/constants/app_constants.dart';

class CustomButton {
  final String name;
  final String command;

  const CustomButton({required this.name, required this.command});

  Map<String, dynamic> toJson() => {'name': name, 'command': command};

  factory CustomButton.fromJson(Map<String, dynamic> json) => CustomButton(
        name: json['name'] as String? ?? '',
        command: json['command'] as String? ?? '',
      );
}

class CommandPanelScreen extends StatefulWidget {
  const CommandPanelScreen({super.key});

  @override
  State<CommandPanelScreen> createState() => _CommandPanelScreenState();
}

class _CommandPanelScreenState extends State<CommandPanelScreen> {
  List<CustomButton> _customButtons = [];
  bool _isExecuting = false;

  final _nameController = TextEditingController();
  final _commandController = TextEditingController();

  static const String _prefsKey = 'custom_buttons_v2';
  static const int _maxButtons = 20;

  // Diyalog içi canlı validasyon
  String? _dialogError;
  bool _dialogTouched = false;

  @override
  void initState() {
    super.initState();
    _loadCustomButtons();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  // ─── SharedPreferences ──────────────────────────────────────────────────

  Future<void> _loadCustomButtons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? json = prefs.getString(_prefsKey);
      if (json != null && mounted) {
        final decoded = jsonDecode(json) as List<dynamic>;
        setState(() {
          _customButtons = decoded
              .map((e) => CustomButton.fromJson(e as Map<String, dynamic>))
              .where((b) => b.name.isNotEmpty && b.command.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCustomButtons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_customButtons.map((b) => b.toJson()).toList()),
      );
    } catch (_) {}
  }

  // ─── Komut Çalıştırma ───────────────────────────────────────────────────

  Future<void> _executeCommand(String command) async {
    final adbClient = context.read<ADBClient>();

    if (!adbClient.isConnected) {
      Fluttertoast.showToast(
        msg: 'Önce bir cihaza bağlanın!',
        backgroundColor: AppConstants.errorRed,
      );
      return;
    }
    if (_isExecuting) return;

    final validation = CommandValidator.validate(command);

    // Hata
    if (!validation.isValid) {
      _showErrorDialog(command, validation.error!);
      return;
    }

    // Kritik komut → onay iste
    if (validation.requiresConfirmation) {
      final confirmed = await _showConfirmDialog(command, validation.warning!);
      if (!confirmed) return;
    }

    setState(() => _isExecuting = true);
    HapticFeedback.lightImpact();

    try {
      final result = await adbClient.executeCommand(command);
      if (mounted && !result.success) {
        Fluttertoast.showToast(
          msg: 'Hata: ${result.error}',
          backgroundColor: AppConstants.errorRed,
        );
      }
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Future<void> _sendKey(KeyCodes keyCode) async {
    await _executeCommand(keyCode.inputCommand);
  }

  // ─── Diyaloglar ─────────────────────────────────────────────────────────

  void _showErrorDialog(String command, String error) {
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
            Icon(Icons.security, color: AppConstants.errorRed, size: 24),
            SizedBox(width: 10),
            Text('Komut Engellendi',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Komut kutusu
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(command,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            // Hata satırları
            ..._errorLines(error),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('TAMAM', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String command, String warning) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                  color: AppConstants.warningOrange, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber,
                    color: AppConstants.warningOrange, size: 24),
                SizedBox(width: 10),
                Text('Dikkat',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(command,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.white70)),
                ),
                const SizedBox(height: 12),
                ..._errorLines(warning),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İPTAL',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.warningOrange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('EVET, ÇALIŞTIR'),
              ),
            ],
          ),
        ) ??
        false;
  }

  List<Widget> _errorLines(String text) {
    return text.split('\n').map((line) {
      final isBullet = line.trim().startsWith('•');
      return Padding(
        padding: EdgeInsets.only(bottom: 4, left: isBullet ? 4 : 0),
        child: Text(line,
            style: TextStyle(
              fontSize: isBullet ? 12 : 13,
              color: isBullet ? Colors.white60 : Colors.white,
              height: 1.4,
            )),
      );
    }).toList();
  }

  // ─── Özel Buton Ekleme ───────────────────────────────────────────────────

  Future<void> _addCustomButton() async {
    if (_customButtons.length >= _maxButtons) {
      Fluttertoast.showToast(
          msg: 'Maksimum $_maxButtons buton ekleyebilirsiniz.');
      return;
    }

    _nameController.clear();
    _commandController.clear();
    _dialogError = null;
    _dialogTouched = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onCmdChanged(String val) {
            if (!_dialogTouched && val.isNotEmpty) _dialogTouched = true;
            if (_dialogTouched) {
              final v = CommandValidator.validate(val.trim());
              setDialogState(() => _dialogError =
                  v.isValid ? null : v.error);
            }
          }

          final cmd = _commandController.text.trim();
          final cmdOk =
              _dialogTouched && _dialogError == null && cmd.isNotEmpty;

          // Validasyon durumu rengi
          Color borderColor = Colors.transparent;
          IconData? suffixIcon;
          Color? suffixColor;
          if (_dialogTouched) {
            if (_dialogError == null) {
              borderColor = AppConstants.successGreen;
              suffixIcon = Icons.check_circle;
              suffixColor = AppConstants.successGreen;
            } else {
              borderColor = AppConstants.errorRed;
              suffixIcon = Icons.cancel;
              suffixColor = AppConstants.errorRed;
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.add_box, color: AppConstants.primaryRed),
                SizedBox(width: 10),
                Text('Yeni Buton Ekle',
                    style: TextStyle(color: Colors.white)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Buton adı
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Buton İsmi',
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: 'örn: Ekranı Aç',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      counterStyle: const TextStyle(color: Colors.grey),
                    ),
                    maxLength: 30,
                  ),
                  const SizedBox(height: 12),

                  // ── Komut alanı (canlı validasyon)
                  TextField(
                    controller: _commandController,
                    style: const TextStyle(
                        fontFamily: 'monospace', color: Colors.white),
                    onChanged: onCmdChanged,
                    decoration: InputDecoration(
                      labelText: 'ADB Shell Komutu',
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: 'örn: input keyevent 26',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: borderColor, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _dialogTouched
                              ? borderColor
                              : AppConstants.primaryRed,
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: suffixIcon != null
                          ? Icon(suffixIcon, color: suffixColor)
                          : null,
                      counterStyle: const TextStyle(color: Colors.grey),
                    ),
                    maxLength: 200,
                  ),

                  // ── Hata kutusu
                  if (_dialogError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.errorRed.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppConstants.errorRed.withAlpha(100)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _dialogError!
                            .split('\n')
                            .map((line) => Text(line,
                                style: TextStyle(
                                  fontSize:
                                      line.trim().startsWith('•') ? 11.5 : 13,
                                  color: line.trim().startsWith('•')
                                      ? Colors.white60
                                      : Colors.redAccent,
                                  height: 1.4,
                                )))
                            .toList(),
                      ),
                    ),
                  ],

                  // ── İpucu (dokunulmamışken)
                  if (!_dialogTouched) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'İpucu: input, am, pm, settings, getprop, wm, dumpsys...',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],

                  // ── Geçerli rozeti
                  if (cmdOk) ...[
                    const SizedBox(height: 8),
                    const Row(children: [
                      Icon(Icons.check_circle,
                          color: AppConstants.successGreen, size: 16),
                      SizedBox(width: 6),
                      Text('Komut geçerli',
                          style: TextStyle(
                              color: AppConstants.successGreen,
                              fontSize: 12)),
                    ]),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İPTAL',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      cmdOk ? AppConstants.primaryRed : Colors.grey[700],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: cmdOk && _nameController.text.trim().isNotEmpty
                    ? () {
                        setState(() => _customButtons.add(CustomButton(
                              name: _nameController.text.trim(),
                              command: _commandController.text.trim(),
                            )));
                        _saveCustomButtons();
                        Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('EKLE'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final adbClient = context.watch<ADBClient>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('KOMUT PANELİ'),
        actions: [
          if (_isExecuting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: _addCustomButton,
            tooltip: 'Özel Buton Ekle',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionBanner(adbClient),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader('ANA NAVİGASYON'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _buildKeyButton('GERİ', Icons.arrow_back,
                        KeyCodes.keyCodeBack, AppConstants.primaryRed),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKeyButton('ANA MENÜ', Icons.home,
                        KeyCodes.keyCodeHome, AppConstants.primaryRed),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader('SES & GÜÇ'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _buildKeyButton('SES +', Icons.volume_up,
                        KeyCodes.keyCodeVolumeUp, AppConstants.successGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKeyButton('SES -', Icons.volume_down,
                        KeyCodes.keyCodeVolumeDown, AppConstants.successGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKeyButton('GÜÇ', Icons.power_settings_new,
                        KeyCodes.keyCodePower, AppConstants.warningOrange),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader('D-PAD'),
                _buildDPad(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                    'ÖZEL BUTONLAR (${_customButtons.length}/$_maxButtons)'),
                const SizedBox(height: 12),
                _buildCustomButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner(ADBClient adbClient) {
    if (adbClient.isConnected) {
      return Container(
        width: double.infinity,
        color: AppConstants.successGreen.withAlpha(30),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.link, color: AppConstants.successGreen, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bağlı: ${adbClient.connectedDevice}',
              style: const TextStyle(
                  color: AppConstants.successGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          if (adbClient.useRoot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppConstants.warningOrange.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppConstants.warningOrange.withAlpha(150)),
              ),
              child: const Text('ROOT',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppConstants.warningOrange,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      color: AppConstants.errorRed.withAlpha(30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(children: [
        Icon(Icons.link_off, color: AppConstants.errorRed, size: 16),
        SizedBox(width: 8),
        Text('Bağlantı yok — komutlar çalışmaz',
            style: TextStyle(
                color: AppConstants.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey));

  Widget _buildKeyButton(
      String label, IconData icon, KeyCodes key, Color color) {
    return ElevatedButton.icon(
      onPressed: _isExecuting ? null : () => _sendKey(key),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withAlpha(100),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDPad() {
    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(children: [
          Positioned(
              top: 0,
              left: 60,
              child: _buildDPadBtn(
                  Icons.arrow_upward, KeyCodes.keyCodeDpadUp)),
          Positioned(
              bottom: 0,
              left: 60,
              child: _buildDPadBtn(
                  Icons.arrow_downward, KeyCodes.keyCodeDpadDown)),
          Positioned(
              left: 0,
              top: 60,
              child: _buildDPadBtn(
                  Icons.arrow_back, KeyCodes.keyCodeDpadLeft)),
          Positioned(
              right: 0,
              top: 60,
              child: _buildDPadBtn(
                  Icons.arrow_forward, KeyCodes.keyCodeDpadRight)),
          Positioned(
              top: 60,
              left: 60,
              child: _buildDPadBtn(Icons.circle, KeyCodes.keyCodeDpadCenter,
                  isCenter: true)),
        ]),
      ),
    );
  }

  Widget _buildDPadBtn(IconData icon, KeyCodes key,
      {bool isCenter = false}) {
    return Material(
      color: isCenter ? AppConstants.primaryRed : AppConstants.surfaceDark,
      borderRadius: BorderRadius.circular(isCenter ? 30 : 8),
      child: InkWell(
        onTap: _isExecuting ? null : () => _sendKey(key),
        borderRadius: BorderRadius.circular(isCenter ? 30 : 8),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Icon(icon,
              color: _isExecuting ? Colors.white38 : Colors.white,
              size: isCenter ? 28 : 24),
        ),
      ),
    );
  }

  Widget _buildCustomButtons() {
    if (_customButtons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Henüz özel buton eklenmedi.\nSağ üstteki + butonuna tıklayın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3,
      ),
      itemCount: _customButtons.length,
      itemBuilder: (context, index) {
        final btn = _customButtons[index];
        return Stack(children: [
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isExecuting ? null : () => _executeCommand(btn.command),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[800],
                disabledBackgroundColor: Colors.blueGrey[900],
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(btn.name,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                setState(() => _customButtons.removeAt(index));
                _saveCustomButtons();
              },
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
