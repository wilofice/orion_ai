import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AudioUploadService {
  final http.Client _client;

  AudioUploadService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> upload(File file) async {
    final region = AppConfig.awsRegion;
    final bucket = AppConfig.awsBucket;
    final accessKey = AppConfig.awsAccessKey;
    final secretKey = AppConfig.awsSecretKey;
    final sessionToken = AppConfig.awsSessionToken;
    
    if (bucket.isEmpty || accessKey.isEmpty || secretKey.isEmpty) {
      throw Exception('AWS S3 configuration is missing');
    }
    
    // Check if temporary credentials are being used
    if (accessKey.startsWith('ASIA') && sessionToken.isEmpty) {
      throw Exception('AWS Session Token is required for temporary credentials');
    }

    final bytes = await file.readAsBytes();
    final key =
        'recordings/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
    final host = '$bucket.s3.$region.amazonaws.com';
    final iso8601 = _formatTimestamp(DateTime.now().toUtc());
    final isoDate = iso8601.substring(0, 8);

    final payloadHash = sha256.convert(bytes).toString();
    final canonicalHeaders = sessionToken.isNotEmpty
        ? 'host:$host\n' 'x-amz-content-sha256:$payloadHash\n' 'x-amz-date:$iso8601\n' 'x-amz-security-token:$sessionToken\n'
        : 'host:$host\n' 'x-amz-content-sha256:$payloadHash\n' 'x-amz-date:$iso8601\n';
    final signedHeaders = sessionToken.isNotEmpty
        ? 'host;x-amz-content-sha256;x-amz-date;x-amz-security-token'
        : 'host;x-amz-content-sha256;x-amz-date';
    final canonicalRequest =
        'PUT\n/$key\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
    final credentialScope = '$isoDate/$region/s3/aws4_request';
    final stringToSign = 'AWS4-HMAC-SHA256\n$iso8601\n$credentialScope\n'
        '${sha256.convert(utf8.encode(canonicalRequest)).toString()}';
    final signingKey = _signingKey(secretKey, isoDate, region, 's3');
    final signature = Hmac(sha256, signingKey)
        .convert(utf8.encode(stringToSign))
        .toString();
    final authorization =
        'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    final uri = Uri.https(host, '/$key');
    final headers = {
      'Authorization': authorization,
      'x-amz-date': iso8601,
      'x-amz-content-sha256': payloadHash,
      'Content-Type': 'audio/m4a',
      'Content-Length': bytes.length.toString(),
    };
    
    if (sessionToken.isNotEmpty) {
      headers['x-amz-security-token'] = sessionToken;
    }
    
    final response = await _client.put(uri, headers: headers, body: bytes);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return 'https://$host/$key';
    } else {
      final errorBody = response.body.isNotEmpty ? response.body : 'No error details';
      throw Exception('S3 upload failed: ${response.statusCode} - $errorBody');
    }
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${y}${m}${d}T${h}${min}${s}Z';
  }

  List<int> _signingKey(String secretKey, String date, String region, String service) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$secretKey')).convert(utf8.encode(date)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }
}
