import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../repositories/settings_repository.dart';
import '../../services/native_bridge.dart';

class TtsSettingsScreen extends StatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  State<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends State<TtsSettingsScreen> {
  final SettingsRepository _settings = SettingsRepository();
  final NativeBridge _nativeBridge = NativeBridge();

  // Available languages
  static const List<Map<String, String>> _languages = [
    {'code': 'en-US', 'name': 'English (US)'},
    {'code': 'en-GB', 'name': 'English (UK)'},
    {'code': 'en-IN', 'name': 'English (India)'},
    {'code': 'hi-IN', 'name': 'Hindi (India)'},
    {'code': 'hinglish', 'name': 'Hinglish (India)'},
    {'code': 'es-ES', 'name': 'Spanish (Spain)'},
    {'code': 'fr-FR', 'name': 'French (France)'},
    {'code': 'de-DE', 'name': 'German (Germany)'},
    {'code': 'ja-JP', 'name': 'Japanese (Japan)'},
    {'code': 'ko-KR', 'name': 'Korean (Korea)'},
    {'code': 'zh-CN', 'name': 'Chinese (Simplified)'},
  ];

  // Test texts in each language
  static const Map<String, String> _testTexts = {
    'en-US': 'This is a test of the text to speech settings.',
    'en-GB': 'This is a test of the text to speech settings.',
    'en-IN': 'This is a test of the text to speech settings.',
    'hi-IN': 'यह टेक्स्ट टू स्पीच सेटिंग्स का एक परीक्षण है।',
    'hinglish': 'Yeh Hinglish feature ka test hai.',
    'es-ES': 'Esta es una prueba de la configuración de texto a voz.',
    'fr-FR': 'Ceci est un test des paramètres de synthèse vocale.',
    'de-DE': 'Dies ist ein Test der Text-zu-Sprache-Einstellungen.',
    'ja-JP': 'これはテキスト読み上げ設定のテストです。',
    'ko-KR': '텍스트 음성 변환 설정 테스트입니다.',
    'zh-CN': '这是文字转语音设置的测试。',
  };

  late String _selectedLanguage;
  late double _speechRate;
  late double _pitch;
  late double _volume;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _selectedLanguage = _settings.getTtsLanguage();
      _speechRate = _settings.getTtsSpeechRate();
      _pitch = _settings.getTtsPitch();
      _volume = _settings.getTtsVolume();
    });
  }

  Future<void> _saveLanguage(String language) async {
    // Check if language is available
    final availability = await _nativeBridge.isLanguageAvailable(language);
    
    if (availability == 'missing_data' || availability == 'not_supported') {
      if (!mounted) return;
      
      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Voice Data Missing"),
          content: Text(
            "The selected language ($language) seems to be missing voice data on your device. \n\n"
            "Would you like to open settings to install it?"
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel/Use anyway
              child: const Text("Use Anyway"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true), // Install
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );

      if (shouldInstall == true) {
        await _nativeBridge.openTtsSettings();
      }
    }
    
    setState(() => _selectedLanguage = language);
    await _settings.setTtsLanguage(language);
  }

  Future<void> _saveSpeechRate(double rate) async {
    setState(() => _speechRate = rate);
    await _settings.setTtsSpeechRate(rate);
  }

  Future<void> _savePitch(double pitch) async {
    setState(() => _pitch = pitch);
    await _settings.setTtsPitch(pitch);
  }

  Future<void> _saveVolume(double volume) async {
    setState(() => _volume = volume);
    await _settings.setTtsVolume(volume);
  }

  Future<void> _testVoice() async {
    setState(() => _isTesting = true);
    try {
      // Use language-specific test text
      final testText = _testTexts[_selectedLanguage] ?? _testTexts['en-US']!;
      final status = await _nativeBridge.testTts(testText);
      
      if (mounted && (status == 'missing_data' || status == 'not_supported')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'missing_data' 
                ? "⚠️ Language voice data missing! Speaking in English. Install voice data from settings."
                : "⚠️ Language not supported! Speaking in English."
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: "Settings",
              textColor: Colors.white,
              onPressed: () => _nativeBridge.openTtsSettings(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error testing voice: $e")),
        );
      }
    }
    // Give it a moment to speak
    await Future.delayed(const Duration(seconds: 3));
    setState(() => _isTesting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TTS Settings'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.volume2, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Text-to-Speech",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Configure how your reminders sound",
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Language Selection
          _buildSectionTitle("Language"),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                icon: const Icon(LucideIcons.chevronDown),
                items: _languages.map((lang) => DropdownMenuItem<String>(
                  value: lang['code'],
                  child: Text(lang['name']!),
                )).toList(),
                onChanged: (value) {
                  if (value != null) _saveLanguage(value);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Note: Language availability depends on your device's TTS engine.",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          
          const SizedBox(height: 32),

          // Speech Rate
          _buildSectionTitle("Speech Rate"),
          const SizedBox(height: 12),
          _buildSliderCard(
            value: _speechRate,
            min: 0.25,
            max: 2.0,
            label: _getSpeechRateLabel(_speechRate),
            icon: LucideIcons.gauge,
            onChanged: (val) => setState(() => _speechRate = val),
            onChangeEnd: _saveSpeechRate,
          ),
          
          const SizedBox(height: 24),

          // Pitch
          _buildSectionTitle("Pitch"),
          const SizedBox(height: 12),
          _buildSliderCard(
            value: _pitch,
            min: 0.5,
            max: 2.0,
            label: _getPitchLabel(_pitch),
            icon: LucideIcons.music,
            onChanged: (val) => setState(() => _pitch = val),
            onChangeEnd: _savePitch,
          ),
          
          const SizedBox(height: 24),

          // Volume
          _buildSectionTitle("Volume"),
          const SizedBox(height: 12),
          _buildSliderCard(
            value: _volume,
            min: 0.0,
            max: 1.0,
            label: "${(_volume * 100).round()}%",
            icon: _volume == 0 ? LucideIcons.volumeX : (_volume < 0.5 ? LucideIcons.volume1 : LucideIcons.volume2),
            onChanged: (val) => setState(() => _volume = val),
            onChangeEnd: _saveVolume,
          ),
          
          const SizedBox(height: 40),

          // Test Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isTesting ? null : _testVoice,
              icon: _isTesting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.play),
              label: Text(_isTesting ? "Speaking..." : "Test Voice"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Reset to defaults
          Center(
            child: TextButton(
              onPressed: () async {
                await _saveLanguage('en-US');
                await _saveSpeechRate(0.75);
                await _savePitch(1.0);
                await _saveVolume(1.0);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("TTS settings reset to defaults")),
                );
              },
              child: const Text("Reset to Defaults"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildSliderCard({
    required double value,
    required double min,
    required double max,
    required String label,
    required IconData icon,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSpeechRateLabel(double rate) {
    if (rate < 0.5) return "Very Slow";
    if (rate < 0.75) return "Slow";
    if (rate < 1.0) return "Normal";
    if (rate < 1.25) return "Fast";
    if (rate < 1.75) return "Very Fast";
    return "Maximum";
  }

  String _getPitchLabel(double pitch) {
    if (pitch < 0.75) return "Low";
    if (pitch < 1.1) return "Normal";
    if (pitch < 1.5) return "High";
    return "Very High";
  }
}
