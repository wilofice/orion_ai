import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening = false;
  String _currentTranscript = '';
  
  // Stream controller for real-time transcription updates
  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;
  
  // Completer for the final result
  Completer<String?>? _resultCompleter;

  Future<bool> initialize() async {
    if (_initialized) return true;
    
    try {
      _initialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: kDebugMode,
      );
      
      if (_initialized) {
        debugPrint('SpeechService: Successfully initialized');
      } else {
        debugPrint('SpeechService: Failed to initialize - speech recognition not available');
      }
      
      return _initialized;
    } catch (e) {
      debugPrint('SpeechService: Error during initialization: $e');
      return false;
    }
  }

  void _onStatus(String status) {
    debugPrint('SpeechService: Status changed to: $status');
    _isListening = status == 'listening';
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('SpeechService: Error occurred: ${error.errorMsg}');
    _isListening = false;
    
    // Complete with null if there's an error and we have an active completer
    if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
      _resultCompleter!.complete(null);
      _resultCompleter = null;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    debugPrint('SpeechService: Result - recognized: ${result.recognizedWords}, final: ${result.finalResult}');
    
    _currentTranscript = result.recognizedWords;
    _transcriptController.add(_currentTranscript);
    
    if (result.finalResult && _resultCompleter != null && !_resultCompleter!.isCompleted) {
      _resultCompleter!.complete(result.recognizedWords);
      _resultCompleter = null;
      stop();
    }
  }

  /// Starts listening for speech and returns the final transcript
  /// This method is designed to work alongside audio recording
  Future<String?> startListening({Duration? timeout}) async {
    if (!await initialize()) {
      debugPrint('SpeechService: Cannot start listening - not initialized');
      return null;
    }
    
    if (_isListening) {
      debugPrint('SpeechService: Already listening');
      return _resultCompleter?.future;
    }
    
    _currentTranscript = '';
    _resultCompleter = Completer<String?>();
    
    try {
      await _speech.listen(
        onResult: _onResult,
        listenFor: timeout ?? const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: null, // Use system default
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
      
      debugPrint('SpeechService: Started listening');
      
      // Set up timeout
      if (timeout != null) {
        Future.delayed(timeout, () {
          if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
            debugPrint('SpeechService: Timeout reached');
            stop();
            _resultCompleter!.complete(_currentTranscript.isNotEmpty ? _currentTranscript : null);
            _resultCompleter = null;
          }
        });
      }
      
      return _resultCompleter!.future;
    } catch (e) {
      debugPrint('SpeechService: Error starting to listen: $e');
      _resultCompleter?.complete(null);
      _resultCompleter = null;
      return null;
    }
  }

  /// Stops listening and returns the current transcript
  String? stop() {
    if (!_isListening) {
      debugPrint('SpeechService: Not currently listening');
      return _currentTranscript.isNotEmpty ? _currentTranscript : null;
    }
    
    try {
      _speech.stop();
      _isListening = false;
      
      // Complete the completer if it hasn't been completed yet
      if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
        _resultCompleter!.complete(_currentTranscript.isNotEmpty ? _currentTranscript : null);
        _resultCompleter = null;
      }
      
      debugPrint('SpeechService: Stopped listening. Final transcript: $_currentTranscript');
      return _currentTranscript.isNotEmpty ? _currentTranscript : null;
    } catch (e) {
      debugPrint('SpeechService: Error stopping: $e');
      return null;
    }
  }

  /// Cancels listening without returning a result
  void cancel() {
    if (_isListening) {
      _speech.cancel();
      _isListening = false;
    }
    
    if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
      _resultCompleter!.complete(null);
      _resultCompleter = null;
    }
    
    _currentTranscript = '';
    debugPrint('SpeechService: Cancelled');
  }

  bool get isListening => _isListening;
  bool get isAvailable => _initialized && _speech.isAvailable;
  String get currentTranscript => _currentTranscript;

  void dispose() {
    cancel();
    _transcriptController.close();
  }
  
  // Legacy method for backward compatibility
  @Deprecated('Use startListening instead')
  Future<String?> listenOnce() async {
    return startListening(timeout: const Duration(seconds: 10));
  }
}