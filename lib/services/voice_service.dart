import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  late stt.SpeechToText _speech;
  bool _isInitialized = false;
  bool get isListening => _speech.isListening;

  VoiceService() {
    _speech = stt.SpeechToText();
  }

  Future<bool> init() async {
    if (_isInitialized) return true;
    
    // Request permission explicitly first using permission_handler for better UX control
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return false;
    }

    try {
      _isInitialized = await _speech.initialize(
        onError: (e) => print('VoiceService Error: ${e.errorMsg}'),
        onStatus: (s) => print('VoiceService Status: $s'),
      );
    } catch (e) {
      print("VoiceService Init Exception: $e");
      return false;
    }
    
    return _isInitialized;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(double) onSoundLevel,
  }) async {
    if (!_isInitialized) {
      bool success = await init();
      if (!success) return;
    }

    await _speech.listen(
      onResult: (val) {
        if (val.recognizedWords.isNotEmpty) {
          onResult(val.recognizedWords);
        }
      },
      onSoundLevelChange: onSoundLevel,
      cancelOnError: true,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> stop() async {
    if (_isInitialized) {
      await _speech.stop();
    }
  }

  Future<void> cancel() async {
    if (_isInitialized) {
      await _speech.cancel();
    }
  }
}
