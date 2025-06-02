import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final Record _record = Record();
  String? _currentPath;

  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<String?> start() async {
    if (!await _requestPermission()) return null;
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _record.start(path: filePath);
    _currentPath = filePath;
    return _currentPath;
  }

  Future<String?> stop() async {
    if (await _record.isRecording()) {
      await _record.stop();
    }
    return _currentPath;
  }
}
