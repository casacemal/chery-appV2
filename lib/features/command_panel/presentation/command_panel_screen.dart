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

  CustomButton({required this.name, required this.command});

  Map<String, dynamic> toJson() => {'name': name, 'command': command};
  factory CustomButton.fromJson(Map<String, dynamic> json) =>
      CustomButton(name: json['name'], command: json['command']);
}

class CommandPanelScreen extends StatefulWidget {
  final ADBClient adbClient;

  const CommandPanelScreen({super.key, required this.adbClient});

  @override
  State<CommandPanelScreen> createState() => _CommandPanelScreenState();
}

class _CommandPanelScreenState extends State<CommandPanelScreen> {
  List<CustomButton> _customButtons = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commandController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomButtons();
  }

  Future<void> _loadCustomButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final String? buttonsJson = prefs.getString('custom_buttons_v2');
    if (buttonsJson != null) {
      final List<dynamic> decoded = jsonDecode(buttonsJson);
      setState(() {
        _customButtons =
            decoded.map((item) => CustomButton.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveCustomButtons() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(_customButtons.map((b) => b.toJson()).toList());
    await prefs.setString('custom_buttons_v2', encoded);
  }

  Future<void> _addCustomButton() async {
    if (_customButtons.length >= 20) {
      Fluttertoast.showToast(msg: 'Maksimum 20 buton ekleyebilirsiniz');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Buton Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Buton İsmi'),
            ),
            TextField(
              controller: _commandController,
              decoration: const InputDecoration(
                  labelText: 'ADB Komutu (shell olmadan)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty &&
                  _commandController.text.isNotEmpty) {
                setState(() {
                  _customButtons.add(CustomButton(
                    name: _nameController.text,
                    command: _commandController.text,
                  ));
                });
                _saveCustomButtons();
                _nameController.clear();
                _commandController.clear();
                Navigator.pop(context);
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
    HapticFeedback.lightImpact();
    final result = await widget.adbClient.executeCommand(command);
    if (!result.success) {
      Fluttertoast.showToast(
          msg: 'Hata: ${result.error}', backgroundColor: AppConstants.errorRed);
    }
  }

  Future<void> _sendKey(KeyCodes keyCode) async {
    _executeCommand(keyCode.inputCommand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KOMUT PANELİ'),
        actions: [
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
                      KeyCodes.keyCodeBack, AppConstants.primaryRed)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildKeyButton('ANA MENÜ', Icons.home,
                      KeyCodes.keyCodeHome, AppConstants.primaryRed)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('SES & GÜÇ'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildKeyButton('SES +', Icons.volume_up,
                      KeyCodes.keyCodeVolumeUp, AppConstants.successGreen)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildKeyButton('SES -', Icons.volume_down,
                      KeyCodes.keyCodeVolumeDown, AppConstants.successGreen)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildKeyButton('GÜÇ', Icons.power_settings_new,
                      KeyCodes.keyCodePower, AppConstants.warningOrange)),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('D-PAD'),
          _buildDPad(),
          const SizedBox(height: 24),
          _buildSectionHeader('ÖZEL BUTONLAR (${_customButtons.length}/20)'),
          const SizedBox(height: 12),
          if (_customButtons.isEmpty)
            const Center(
                child: Text('Henüz özel buton eklenmedi',
                    style: TextStyle(color: Colors.grey)))
          else
            GridView.builder(
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
                        onPressed: () => _executeCommand(btn.command),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[800],
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(btn.name,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
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
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
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
      onPressed: () => _sendKey(key),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
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
        onTap: () => _sendKey(key),
        borderRadius: BorderRadius.circular(isCenter ? 30 : 8),
        child: SizedBox(
            width: 60,
            height: 60,
            child: Icon(icon, color: Colors.white, size: isCenter ? 28 : 24)),
      ),
    );
  }
}
