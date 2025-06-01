import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  Future<bool> _init() async {
    if (!_initialized) {
      _initialized = await _speech.initialize();
    }
    return _initialized;
  }

  Future<String?> listenOnce() async {
    if (!await _init()) return null;
    final completer = Completer<String?>();
    _speech.listen(onResult: (result) {
      if (result.finalResult) {
        _speech.stop();
        completer.complete(result.recognizedWords);
      }
    });
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      _speech.stop();
      return null;
    });
  }

  void stop() {
    _speech.stop();
  }
}
