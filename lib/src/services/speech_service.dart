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
  final List<String> _transcriptSegments = [];
  Duration? _targetTimeout;
  DateTime? _startTime;
  Timer? _timeoutTimer;
  
  // Stream controller for real-time transcription updates
  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;
  
  // Completer for the final result
  Completer<String?>? _resultCompleter;

  Future<bool> initialize() async {
    if (_initialized) return true;
    
    try {
      // Check if speech recognition is available on this device
      bool available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: kDebugMode,
        finalTimeout: const Duration(seconds: 360), // Disable automatic timeout
      );
      
      if (available) {
        // Additional check for microphone permission
        bool hasPermission = await _speech.hasPermission;
        if (!hasPermission) {
          debugPrint('SpeechService: No microphone permission');
          return false;
        }
        
        _initialized = true;
        debugPrint('SpeechService: Successfully initialized with permission');
      } else {
        debugPrint('SpeechService: Speech recognition not available on this device');
      }
      
      return _initialized;
    } catch (e) {
      debugPrint('SpeechService: Error during initialization: $e');
      _initialized = false;
      return false;
    }
  }

  void _onStatus(String status) {
    debugPrint('SpeechService: Status changed to: $status');
    _isListening = status == 'listening';
  }

  void _onError(SpeechRecognitionError error) {
    debugPrint('SpeechService: Error occurred: ${error.errorMsg} (type: ${error.errorMsg})');
    _isListening = false;

    switch (error.errorMsg) {
      case 'error_no_match':
        debugPrint('SpeechService: No speech detected');
        break;
      case 'error_audio':
        debugPrint('SpeechService: Audio error - check microphone permissions');
        break;
      default:
        debugPrint('SpeechService: Unknown error type: ${error.errorMsg}');
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    debugPrint('SpeechService: Result - recognized: ${result.recognizedWords}, final: ${result.finalResult}');

    _currentTranscript = result.recognizedWords;

    // Build interim transcript for streaming
    final interim = (_transcriptSegments + [if (!result.finalResult) _currentTranscript]).join(' ').trim();
    _transcriptController.add(interim);

    if (result.finalResult) {
      _transcriptSegments.add(result.recognizedWords);
      _currentTranscript = '';

      final remaining = _remainingTimeout();
      if (remaining == null || remaining > Duration.zero) {
        // Restart listening to overcome Android pause timeout
        _startListeningInternal(remaining);
      } else {
        stop();
      }
    }
  }

  Duration? _remainingTimeout() {
    if (_targetTimeout == null || _startTime == null) return _targetTimeout;
    final elapsed = DateTime.now().difference(_startTime!);
    final remaining = _targetTimeout! - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _startListeningInternal(Duration? remaining) async {
    final duration = remaining == null || remaining <= Duration.zero ? null : remaining;
    try {
      await _speech.listen(
        onResult: _onResult,
        listenFor: duration,
        pauseFor: const Duration(seconds: 360),
        listenOptions: stt.SpeechListenOptions(
          partialResults: false,
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    } catch (e) {
      debugPrint('SpeechService: Error starting internal listen: $e');
    }
  }

  /// Starts listening for speech and returns the final transcript when [stop]
  /// is called or when [timeout] is reached. On Android, listening is
  /// automatically restarted whenever it stops due to the platform's short
  /// pause timeout.
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
    _transcriptSegments.clear();
    _resultCompleter = Completer<String?>();
    _targetTimeout = timeout;
    _startTime = DateTime.now();

    _timeoutTimer?.cancel();
    if (timeout != null) {
      _timeoutTimer = Timer(timeout, () {
        if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
          debugPrint('SpeechService: Manual timeout reached');
          final result = stop();
          if (!_resultCompleter!.isCompleted) {
            _resultCompleter!.complete(result);
          }
        }
      });
    }

    try {
      await _startListeningInternal(timeout);
      debugPrint('SpeechService: Started listening with restart support');
      return _resultCompleter!.future;
    } catch (e) {
      debugPrint('SpeechService: Error starting to listen: $e');

      // Try fallback with minimal configuration
      try {
        debugPrint('SpeechService: Trying fallback configuration');
        await _speech.listen(onResult: _onResult);

        Future.delayed(const Duration(seconds: 10), () {
          if (_resultCompleter != null && !_resultCompleter!.isCompleted) {
            final result = stop();
            if (!_resultCompleter!.isCompleted) {
              _resultCompleter!.complete(result);
            }
          }
        });

        return _resultCompleter!.future;
      } catch (fallbackError) {
        debugPrint('SpeechService: Fallback also failed: $fallbackError');
        _resultCompleter?.complete(null);
        _resultCompleter = null;
        return null;
      }
    }
  }

  /// Stops listening and returns the concatenated transcript of all segments
  String? stop() {
    final alreadyCompleted = _resultCompleter == null || _resultCompleter!.isCompleted;

    try {
      _timeoutTimer?.cancel();
      _speech.stop();
      _isListening = false;

      final finalTranscript = (_transcriptSegments + [_currentTranscript]).join(' ').trim();

      if (!alreadyCompleted && _resultCompleter != null) {
        _resultCompleter!.complete(finalTranscript.isNotEmpty ? finalTranscript : null);
        _resultCompleter = null;
      }

      debugPrint('SpeechService: Stopped listening. Final transcript: $finalTranscript');

      _transcriptSegments.clear();
      _currentTranscript = '';

      return finalTranscript.isNotEmpty ? finalTranscript : null;
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

    _timeoutTimer?.cancel();
    _transcriptSegments.clear();
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