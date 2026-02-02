import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsRepository {
  static const String _boxName = 'settings';
  static const String _keyThemeMode = 'theme_mode';
  
  // TTS Settings Keys
  static const String _keyTtsLanguage = 'tts_language';
  static const String _keyTtsSpeechRate = 'tts_speech_rate';
  static const String _keyTtsPitch = 'tts_pitch';
  static const String _keyTtsVolume = 'tts_volume';

  static final SettingsRepository _instance = SettingsRepository._internal();

  factory SettingsRepository() {
    return _instance;
  }

  SettingsRepository._internal();

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// Helper to get user-specific key
  String _getKey(String baseKey) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return baseKey; // Fallback for unauthenticated (shouldn't happen in main app)
    return '${user.uid}_$baseKey';
  }

  /// Returns a ValueListenable for the theme mode, so widgets can rebuild on change.
  /// Note: ValueListenable for dynamic keys is tricky with Hive directly if we want to listen to *current* user's key.
  /// For now, we listen to the box generally, or we could implement a custom notifier.
  /// Simplified: We'll just return box listenable, and widgets will rebuild.
  ValueListenable<Box> get themeModeListenable => _box.listenable();

  ThemeMode getThemeMode() {
    final key = _getKey(_keyThemeMode);
    final storedValue = _box.get(key, defaultValue: 'system') as String;
    switch (storedValue) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    await _box.put(_getKey(_keyThemeMode), value);
  }

  // ==================== TTS Settings ====================

  /// Get TTS language locale string (e.g., "en-US", "hi-IN")
  String getTtsLanguage() {
    return _box.get(_getKey(_keyTtsLanguage), defaultValue: 'en-US') as String;
  }

  Future<void> setTtsLanguage(String language) async {
    await _box.put(_getKey(_keyTtsLanguage), language);
  }

  /// Get TTS speech rate (0.25 to 2.0, default 0.75)
  double getTtsSpeechRate() {
    return _box.get(_getKey(_keyTtsSpeechRate), defaultValue: 0.75) as double;
  }

  Future<void> setTtsSpeechRate(double rate) async {
    await _box.put(_getKey(_keyTtsSpeechRate), rate);
  }

  /// Get TTS pitch (0.5 to 2.0, default 1.0)
  double getTtsPitch() {
    return _box.get(_getKey(_keyTtsPitch), defaultValue: 1.0) as double;
  }

  Future<void> setTtsPitch(double pitch) async {
    await _box.put(_getKey(_keyTtsPitch), pitch);
  }

  /// Get TTS volume (0.0 to 1.0, default 1.0)
  double getTtsVolume() {
    return _box.get(_getKey(_keyTtsVolume), defaultValue: 1.0) as double;
  }

  Future<void> setTtsVolume(double volume) async {
    await _box.put(_getKey(_keyTtsVolume), volume);
  }

  /// Get all TTS settings as a map for passing to native
  Map<String, dynamic> getTtsSettings() {
    return {
      'language': getTtsLanguage(),
      'speechRate': getTtsSpeechRate(),
      'pitch': getTtsPitch(),
      'volume': getTtsVolume(),
    };
  }
}
