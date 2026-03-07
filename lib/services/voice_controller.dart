import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceController {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  Future<bool> initSpeech() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      _isAvailable = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );
    }
    return _isAvailable;
  }

  void startListening(Function(String) onResult) {
    if (_isAvailable) {
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            final text = result.recognizedWords.toLowerCase();
            onResult(text);
          }
        },
        localeId: 'pl_PL', // Polish language as requested
      );
    }
  }

  void stopListening() {
    _speech.stop();
  }

  bool get isListening => _speech.isListening;
}
