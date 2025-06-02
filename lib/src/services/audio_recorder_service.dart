import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart'; // Ensure this is 'package:record/record.dart'

class AudioRecorderService {
  // Use AudioRecorder instead of Record
  final AudioRecorder _audioRecorder;
  String? _currentRecordingPath;
  bool _isInitialized = false;

  // A simple way to expose recording state if needed by the UI
  // For more complex UI updates, consider using a ChangeNotifier or other state management
  bool get isRecording => _isRecordingValue;
  bool _isRecordingValue = false; // Internal state

  AudioRecorderService() : _audioRecorder = AudioRecorder() {
    // You can listen to state changes if needed
    // _audioRecorder.onStateChanged().listen((recordState) {
    //   _isRecordingValue = recordState == RecordState.record;
    //   // If using ChangeNotifier, you would call notifyListeners() here
    //   print("Recorder state changed: $recordState");
    // });
  }

  // Initialize any async setup if needed, though not strictly required for this basic setup
  Future<void> initialize() async {
    // Future placeholder for any async init steps
    _isInitialized = true;
    print("AudioRecorderService initialized.");
  }

  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isDenied || status.isPermanentlyDenied || status.isRestricted) {
      print("Microphone permission denied. Status: $status");
      // Optionally, prompt the user to open app settings
      // if (status.isPermanentlyDenied) {
      //   openAppSettings();
      // }
      return false;
    }
    return status.isGranted;
  }

  Future<String?> startRecording() async {
    if (!_isInitialized) {
      print("Service not initialized. Call initialize() first.");
      // Or implicitly initialize: await initialize();
      return null;
    }

    if (await _audioRecorder.isRecording()) {
      print("Already recording.");
      return _currentRecordingPath;
    }

    if (!await _requestMicrophonePermission()) {
      print("Microphone permission not granted.");
      return null;
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      // Using .m4a (AAC) format. Adjust extension and encoder for other formats.
      final filePath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Configure the recording.
      // For M4A (AAC audio), use AudioEncoder.aacLc or AudioEncoder.aacHe
      // For other formats like WAV (PCM), you might use AudioEncoder.pcm16bits (ensure supported by platform)
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // Good for .m4a
        // sampleRate: 44100, // Optional
        // bitRate: 128000,    // Optional
        // numChannels: 1,     // Optional
      );

      // Start recording to the specified path with the given configuration.
      await _audioRecorder.start(config, path: filePath);
      _currentRecordingPath = filePath;
      _isRecordingValue = true; // Update state
      print("Started recording to: $filePath");
      return _currentRecordingPath;
    } catch (e, s) {
      print("Error starting recording: $e");
      print("Stack trace: $s");
      _currentRecordingPath = null;
      _isRecordingValue = false; // Update state
      return null;
    }
  }

  Future<String?> stopRecording() async {
    if (!await _audioRecorder.isRecording()) {
      print("Not currently recording or recording has already been stopped.");
      // Return the last known path, or null if you prefer to signify no active stop occurred.
      return _currentRecordingPath;
    }

    try {
      // The stop method returns the path to the completed recording.
      final String? path = await _audioRecorder.stop();
      _isRecordingValue = false; // Update state
      if (path != null) {
        _currentRecordingPath = path; // Update with the path returned by stop()
        print("Recording stopped. File saved at: $path");
      } else {
        print("Recording stopped, but path was null (this might indicate an issue).");
        // _currentRecordingPath might still hold the path used in start()
      }
      return _currentRecordingPath;
    } catch (e, s) {
      print("Error stopping recording: $e");
      print("Stack trace: $s");
      _isRecordingValue = false; // Update state
      return null; // Or return _currentRecordingPath if you want to provide the last attempted path
    }
  }

  // Call this method when the service is no longer needed to release resources.
  Future<void> dispose() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop(); // Stop recording if active before disposing
    }
    await _audioRecorder.dispose();
    _isRecordingValue = false;
    print("AudioRecorderService disposed.");
  }
}