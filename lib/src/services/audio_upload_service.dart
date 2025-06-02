import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth_provider.dart';
import '../config.dart';

class AudioUploadService {
  final http.Client _client;
  final AuthProvider _authProvider;

  AudioUploadService({http.Client? client, required AuthProvider authProvider})
      : _client = client ?? http.Client(),
        _authProvider = authProvider;

  Future<String> upload(File file) async {
    final token = _authProvider.backendAccessToken;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final name = file.uri.pathSegments.last;
    final presignRes = await _client.post(
      Uri.parse('${AppConfig.backendApiBaseUrl}/media/presign'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'file_name': name}),
    );

    if (presignRes.statusCode != 200) {
      throw Exception('Failed to obtain upload url');
    }
    final presignBody = jsonDecode(presignRes.body) as Map<String, dynamic>;
    final url = presignBody['url'] as String?;
    if (url == null) throw Exception('No url returned');

    final bytes = await file.readAsBytes();
    final uploadRes = await _client.put(
      Uri.parse(url),
      headers: {'Content-Type': 'audio/m4a'},
      body: bytes,
    );

    if (uploadRes.statusCode < 200 || uploadRes.statusCode >= 300) {
      throw Exception('Upload failed');
    }

    return url.split('?').first;
  }
}
