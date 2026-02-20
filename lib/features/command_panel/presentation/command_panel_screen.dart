import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/adb/adb_client.dart';
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
  final ADBClient adbClient;

  const CommandPanelScreen({super.key, required this.adbClient});

  @override
  State<CommandPanelScreen> createState() => _CommandPanelScreenState();
}

class _CommandPanelScreenState extends State<CommandPanelScreen> {
  List<CustomButton> _customButtons = [];
  bool _isExecuting = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();

  static const String _prefsKey = 'custom_buttons_v2';
  static const int _maxButtons = 20;

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

  Future<void> _loadCustomButtons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? buttonsJson = prefs.getString(_prefsKey);
      if (buttonsJson != null && mounted) {
        final List<dynamic> decoded = jsonDecode(buttonsJson);
        setState(() {
          _customButtons = decoded
              .map((item) =>
                  CustomButton.fromJson(item as Map<String, dynamic>))
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

  Future<void> _addCustomButton() async {
    if (_customButtons.length >= _maxButtons) {
      Fluttertoast.showToast(msg: 'Maksimum $_maxButtons buton ekleyebilirsiniz');
      return;
    }

    _nameController.clear();
    _commandController.clear();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Buton Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Buton İsmi',
                hintText: 'örn: Ekran Açık',
              ),
              maxLength: 30,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commandController,
              decoration: const InputDecoration(
                labelText: 'ADB Shell Komutu',
                hintText: 'örn: input keyevent 26',
              ),
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final cmd = _commandController.text.trim();
              if (name.isNotEmpty && cmd.isNotEmpty) {
                setState(() => _customButtons
                    .add(CustomButton(name: name, command: cmd)));
                _saveCustomButtons();
                Navigator.pop(ctx);
              }
            },
            child: const Text('EKLE'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeCommand(String command) async {
    if (!widget.adbClient.isConnected) {
      Fluttertoast.showToast(
          msg: 'Önce bir cihaza bağlanın!',
          backgroundColor: AppConstants.errorRed);
      return;
    }
    if (_isExecuting) return;

    setState(() => _isExecuting = true);
    HapticFeedback.lightImpact();

    try {
      final result = await widget.adbClient.executeCommand(command);
      if (mounted && !result.success) {
        Fluttertoast.showToast(
            msg: 'Hata: ${result.error}',
            backgroundColor: AppConstants.errorRed);
      }
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Future<void> _sendKey(KeyCodes keyCode) async {
    await _executeCommand(keyCode.inputCommand);
  }

  @override
  Widget build(BuildContext context) {
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('ANA NAVİGASYON'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKeyButton('GERİ', Icons.arrow_back,
                    KeyCodes.keyCodeBack, AppConstants.primaryRed),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKeyButton('ANA MENÜ', Icons.home,
                    KeyCodes.keyCodeHome, AppConstants.primaryRed),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('SES & GÜÇ'),
          const SizedBox(height: 12),
          Row(
            children: [
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
            ],
          ),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey));
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildDPad() {
    return Center(
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 60,
              child: _buildDPadBtn(Icons.arrow_upward, KeyCodes.keyCodeDpadUp),
            ),
            Positioned(
              bottom: 0,
              left: 60,
              child: _buildDPadBtn(
                  Icons.arrow_downward, KeyCodes.keyCodeDpadDown),
            ),
            Positioned(
              left: 0,
              top: 60,
              child: _buildDPadBtn(Icons.arrow_back, KeyCodes.keyCodeDpadLeft),
            ),
            Positioned(
              right: 0,
              top: 60,
              child: _buildDPadBtn(
                  Icons.arrow_forward, KeyCodes.keyCodeDpadRight),
            ),
            Positioned(
              top: 60,
              left: 60,
              child: _buildDPadBtn(Icons.circle, KeyCodes.keyCodeDpadCenter,
                  isCenter: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDPadBtn(IconData icon, KeyCodes key, {bool isCenter = false}) {
    return Material(
      color: isCenter ? AppConstants.primaryRed : AppConstants.surfaceDark,
      borderRadius: BorderRadius.circular(isCenter ? 30 : 8),
      child: InkWell(
        onTap: _isExecuting ? null : () => _sendKey(key),
        borderRadius: BorderRadius.circular(isCenter ? 30 : 8),
        child: SizedBox(
          width: 60,
          height: 60,
          child: Icon(
            icon,
            color: _isExecuting ? Colors.white38 : Colors.white,
            size: isCenter ? 28 : 24,
          ),
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
        return Stack(
          children: [
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
                  child:
                      const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
