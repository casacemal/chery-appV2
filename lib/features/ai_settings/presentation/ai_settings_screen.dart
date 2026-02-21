import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/ai/ai_settings_storage.dart';
import '../../../core/ai/groq_service.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final _storage = AISettingsStorage();
  final _apiKeyController = TextEditingController();
  final _promptController = TextEditingController();

  bool _obscureKey = true;
  bool _isTesting = false;
  bool _isSaving = false;
  String _testStatus = ''; // '', 'success', 'failed'

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final key = await _storage.getApiKey();
    final prompt = await _storage.getPrompt();
    if (mounted) {
      setState(() {
        _apiKeyController.text = key ?? '';
        _promptController.text = prompt;
      });
    }
  }

  Future<void> _save() async {
    final key = _apiKeyController.text.trim();
    final prompt = _promptController.text.trim();

    if (key.isEmpty) {
      Fluttertoast.showToast(
          msg: 'API key boş olamaz',
          backgroundColor: AppConstants.errorRed);
      return;
    }

    setState(() => _isSaving = true);
    await _storage.saveApiKey(key);
    await _storage.savePrompt(prompt.isEmpty
        ? AISettingsStorage.defaultPrompt
        : prompt);
    setState(() => _isSaving = false);

    Fluttertoast.showToast(
        msg: 'Ayarlar kaydedildi',
        backgroundColor: AppConstants.successGreen);
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      Fluttertoast.showToast(
          msg: 'Önce API key girin',
          backgroundColor: AppConstants.errorRed);
      return;
    }

    setState(() {
      _isTesting = true;
      _testStatus = '';
    });

    final service = GroqService(
      apiKey: key,
      prompt: _promptController.text,
    );
    final ok = await service.testConnection();

    setState(() {
      _isTesting = false;
      _testStatus = ok ? 'success' : 'failed';
    });
  }

  Future<void> _resetPrompt() async {
    setState(() =>
        _promptController.text = AISettingsStorage.defaultPrompt);
    Fluttertoast.showToast(msg: 'Prompt varsayılana sıfırlandı');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology, size: 22),
            SizedBox(width: 8),
            Text('AI AYARLARI'),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: 'Kaydet',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── API Key ──────────────────────────────────────────────────────
          _buildSectionHeader('GROQ API KEY'),
          const SizedBox(height: 8),
          const Text(
            'console.groq.com → API Keys → Create key',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppConstants.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'gsk_...',
                hintStyle:
                    const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Test butonu
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: Text(_isTesting ? 'Test ediliyor...' : 'Bağlantıyı Test Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
                  ),
                ),
              ),
              if (_testStatus.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(
                  _testStatus == 'success'
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _testStatus == 'success'
                      ? AppConstants.successGreen
                      : AppConstants.errorRed,
                  size: 28,
                ),
              ]
            ],
          ),

          const SizedBox(height: 28),

          // ── Prompt ───────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('PROMPT'),
              TextButton.icon(
                onPressed: _resetPrompt,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Sıfırla', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '{command} ve {output} yer tutucuları otomatik doldurulur.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppConstants.surfaceDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _promptController,
              maxLines: 12,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, height: 1.5),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Kaydet butonu (alt)
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('KAYDET'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1));
  }
}
