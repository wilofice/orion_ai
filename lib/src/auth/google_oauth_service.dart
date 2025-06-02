import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config.dart';

class GoogleOAuthService {
  GoogleOAuthService._();

  static final String googleClientIdIos =
      dotenv.env['GOOGLE_CLIENT_ID_IOS'] ?? '';
  static final String googleClientIdAndroid =
      dotenv.env['GOOGLE_CLIENT_ID_ANDROID'] ?? '';

  static const String customUriSchemeIos =
      'com.googleusercontent.apps.242901186197-k0kflho05ctojg9da4vuvf88fe7c6d1b';
  static const String customUriSchemeAndroid =
      'com.googleusercontent.apps.242901186197-b59i14n5oodp6e54t5iptcl1j1d91ql8';
  static const String redirectUriIos = '$customUriSchemeIos:/oauth2redirect';
  static const String redirectUriAndroid =
      '$customUriSchemeAndroid:/oauth2redirect';

  static const List<String> googleScopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar',
  ];

  static final String backendApiBaseUrl = AppConfig.backendApiBaseUrl;
  static const String googleConnectEndpoint = '/auth/google/connect';

  static String _generateRandomString(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static Future<Map<String, dynamic>> signInWithGoogle(
      BuildContext context) async {
    final String codeVerifier = _generateRandomString(32);
    final String codeChallenge = _generateCodeChallenge(codeVerifier);
    final String state = _generateRandomString(16);

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': Platform.isIOS ? googleClientIdIos : googleClientIdAndroid,
      'response_type': 'code',
      'redirect_uri':
          Platform.isIOS ? redirectUriIos : redirectUriAndroid,
      'scope': googleScopes.join(' '),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      'access_type': 'offline',
      'prompt': 'consent',
    });

    final resultUrlString = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme:
          Platform.isIOS ? customUriSchemeIos : customUriSchemeAndroid,
      options: const FlutterWebAuth2Options(
        preferEphemeral: true,
        debugOrigin: null,
        intentFlags: ephemeralIntentFlags,
        timeout: 15,
        landingPageHtml: null,
        silentAuth: false,
      ),
    );

    final Uri resultUri = Uri.parse(resultUrlString);
    if (resultUri.queryParameters['state'] != state) {
      throw Exception('Invalid state returned');
    }

    final String? tempAuthCode = resultUri.queryParameters['code'];
    if (tempAuthCode == null || tempAuthCode.isEmpty) {
      final error = resultUri.queryParameters['error'] ??
          'Authentication failed unexpectedly';
      throw Exception(error);
    }

    return _sendCodeAndVerifierToBackend(context, tempAuthCode, codeVerifier);
  }

  static Future<Map<String, dynamic>> _sendCodeAndVerifierToBackend(
    BuildContext context,
    String authCode,
    String pkceVerifier,
  ) async {
    final String backendUrl = backendApiBaseUrl + googleConnectEndpoint;

    final Map<String, String> requestBody = {
      'authorization_code': authCode,
      'code_verifier': pkceVerifier,
      'redirect_uri': Platform.isIOS ? redirectUriIos : redirectUriAndroid,
      'platform': Platform.isIOS ? 'ios' : 'android',
    };
    final payload = {'payload': requestBody};

    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      String errorMsg = 'Failed to connect with backend.';
      try {
        final responseBody = jsonDecode(response.body);
        errorMsg = responseBody['error'] ??
            responseBody['message'] ??
            'Backend error: ${response.statusCode}';
      } catch (_) {
        errorMsg =
            'Backend error: ${response.statusCode}. Invalid response format.';
      }
      throw Exception(errorMsg);
    }
  }
}
