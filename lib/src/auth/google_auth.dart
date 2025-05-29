import 'dart:convert'; // For base64 encoding, jsonEncode
import 'dart:math'; // For random string generation
import 'package:crypto/crypto.dart'; // For SHA256
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart'; // For web authentication
import 'package:http/http.dart' as http; // For making HTTP requests to the backend
import 'package:orion_ai/src/auth/auth_provider.dart';
import 'package:orion_ai/src/chat/chat_screen.dart'; // Import your chat screen
import 'package:orion_ai/src/chat/chat_provider.dart'; // Import your chat screen
import 'package:orion_ai/src/services/chat_service.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For app's own session tokens (if needed for backend auth)

import 'dart:io';

import 'package:provider/provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthConfig {
  static final String googleClientIdIos = dotenv.env['GOOGLE_CLIENT_ID_IOS'] ?? '';
  static final String googleClientIdAndroid = dotenv.env['GOOGLE_CLIENT_ID_ANDROID'] ?? '';
}

class GoogleAuthScreen extends StatefulWidget {
  const GoogleAuthScreen({super.key});

  @override
  State<GoogleAuthScreen> createState() => _GoogleAuthScreenState();
}

class _GoogleAuthScreenState extends State<GoogleAuthScreen> {
  String _status = 'Not Connected. Please configure Client ID and URI Scheme.';
  String? _codeVerifier;
  String? _authorizationCode;
  String? _errorMessage;
  bool _isLoading = false; // To show a loading indicator during backend call

  // --- Configuration (MUST BE REPLACED) ---242901186197-b59i14n5oodp6e54t5iptcl1j1d91ql8.apps.googleusercontent.com
  static String googleClientIdIos = GoogleAuthConfig.googleClientIdIos; // <<<< REPLACE THIS
  static String googleClientIdAndroid = GoogleAuthConfig.googleClientIdAndroid; // <<<< REPLACE THIS
  static const String customUriSchemeIos = "com.googleusercontent.apps.242901186197-k0kflho05ctojg9da4vuvf88fe7c6d1b"; // <<<< REPLACE THIS
  static const String customUriSchemeAndroid = "com.example.orionAi";
  static const String redirectUriIos = "$customUriSchemeIos:/oauth2redirect";
  static const String redirectUriAndroid = "$customUriSchemeAndroid:/oauth2redirect";
  static const List<String> googleScopes = [
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/calendar',
  ];
  // --- Backend Configuration (MUST BE REPLACED) ---
  //static const String backendApiBaseUrl = "http://192.168.1.22:8001/Prod";
  static const String backendApiBaseUrl = "https://ww62jfo5jh.execute-api.eu-north-1.amazonaws.com/Prod"; // <<<< REPLACE THIS (e.g., https://api.yourapp.com)
   // <<<< REPLACE THIS (e.g., https://api.yourapp.com)
  static const String googleConnectEndpoint =
      "/auth/google/connect"; // Example endpoint path
  // --- End Configuration ---

  @override
  void initState() {
    super.initState();
    if (backendApiBaseUrl == "YOUR_BACKEND_API_ENDPOINT") {
      _status = 'Configuration Required!';
      _errorMessage =
          'Please update `googleClientId`, `customUriScheme`, and `backendApiBaseUrl` in `google_auth_screen.dart` with your actual values. Also, ensure platform configurations are set up.';
    } else {
      _status = 'Ready to Connect.';
    }
  }

  String _generateRandomString(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  void _generateCodeVerifier() {
    _codeVerifier = _generateRandomString(32);
    debugPrint("Generated PKCE Code Verifier: $_codeVerifier");
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _handleGoogleConnect() async {
    setState(() {
      _isLoading = true; // Start loading before auth flow
      _status = 'Initiating Connection...';
      _errorMessage = null;
      _authorizationCode = null;
    });

    if (backendApiBaseUrl == "YOUR_BACKEND_API_ENDPOINT") {
      setState(() {
        _isLoading = false;
        _status = 'Configuration Error';
        _errorMessage =
            'CRITICAL: Ensure `googleClientId`, `customUriScheme`, `backendApiBaseUrl` are correctly set and `redirectUri` uses the scheme. Check platform setup (AndroidManifest.xml/Info.plist).';
      });
      _showErrorSnackbar(_errorMessage!);
      return;
    }

    _generateCodeVerifier();
    if (_codeVerifier == null) {
      setState(() {
        _isLoading = false;
        _status = 'Error: PKCE Verifier Generation Failed.';
        _errorMessage = 'Could not generate the PKCE code verifier.';
      });
      _showErrorSnackbar(_errorMessage!);
      return;
    }

    final String codeChallenge = _generateCodeChallenge(_codeVerifier!);
    final String state = _generateRandomString(16);

    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': Platform.isIOS
          ? googleClientIdIos
          : googleClientIdAndroid,
      'response_type': 'code',
      'redirect_uri': Platform.isIOS
          ? redirectUriIos
          : redirectUriAndroid,
      'scope': googleScopes.join(' '),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      'access_type': 'offline',
      'prompt': 'consent',
    });

    debugPrint("Attempting to authenticate with URL: $authUrl");

    try {
      final resultUrlString = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: Platform.isIOS
            ? customUriSchemeIos
            : customUriSchemeAndroid,
      );
      debugPrint("Authentication Result URL: $resultUrlString");

      final Uri resultUri = Uri.parse(resultUrlString);
      final returnedState = resultUri.queryParameters['state'];

      if (returnedState != state) {
        setState(() {
          _isLoading = false;
          _status = 'Error: Invalid State Parameter (CSRF suspected).';
          _errorMessage =
              'The state parameter from the authentication response does not match. Authentication aborted.';
        });
        debugPrint(
          "Error: State mismatch. Original: $state, Returned: $returnedState",
        );
        _showErrorSnackbar(_errorMessage!);
        return;
      }

      final String? tempAuthCode = resultUri.queryParameters['code'];
      final error = resultUri.queryParameters['error'];

      if (tempAuthCode != null && tempAuthCode.isNotEmpty) {
        setState(() {
          _authorizationCode = tempAuthCode; // Store auth code
          _status = 'Authorization Code Received. Sending to backend...';
          _errorMessage = null;
          debugPrint('Authorization Code: $_authorizationCode');
          debugPrint('PKCE Verifier (to be sent to backend): $_codeVerifier');
        });
        // Call method to send code and verifier to backend
        await _sendCodeAndVerifierToBackend(
          _authorizationCode!,
          _codeVerifier!
        );
      } else if (error != null) {
        final errorDescription =
            resultUri.queryParameters['error_description'] ??
            'No additional details.';
        setState(() {
          _isLoading = false;
          _status = 'Authentication Error from Google.';
          _errorMessage =
              'Google authentication failed: "$error". Description: "$errorDescription"';
        });
        debugPrint(
          'Google authentication error: $error. Description: $errorDescription. URI: $resultUri',
        );
        _showErrorSnackbar(_errorMessage!);
      } else {
        setState(() {
          _isLoading = false;
          _status = 'Error: Authentication Failed Unexpectedly.';
          _errorMessage =
              'No authorization code or error was found in Google\'s response.';
        });
        debugPrint(
          'Authentication failed. No code or error in response URI: $resultUri',
        );
        _showErrorSnackbar(_errorMessage!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: Authentication Exception.';
        _errorMessage =
            'An exception occurred during web authentication: ${e.toString()}';
      });
      debugPrint('Authentication exception: $e');
      _showErrorSnackbar(_errorMessage!);
    }
  }

  // Method to send the authorization code and PKCE verifier to your backend.
  Future<void> _sendCodeAndVerifierToBackend(
    String authCode,
    String pkceVerifier
  ) async {
    // Ensure isLoading is true when this function starts
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _status =
            'Sending code to backend...'; // Update status if not already set by caller
      });
    }

    final String backendUrl = backendApiBaseUrl + googleConnectEndpoint;
    debugPrint("Sending code to backend URL: $backendUrl");

    try {
      // Prepare the request body
      final Map<String, String> requestBody = {
        'authorization_code': authCode,
        'code_verifier': pkceVerifier,
        'redirect_uri': Platform.isIOS ? redirectUriIos : redirectUriAndroid, // The backend needs this to verify the request with Google
        'platform': Platform.isIOS ? 'ios' : 'android',
      };

      // Make the POST request
      final response = await http.post(
        Uri.parse(backendUrl), // Ensure the URL is correctly parsed
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          // If your backend requires authentication for this endpoint (e.g., your app's session token),
          // you would add it here:
          // 'Authorization': 'Bearer YOUR_APP_SESSION_TOKEN',
        },
        body: jsonEncode(requestBody), // Encode the body to JSON
      );

      // Process the response
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Successfully connected with backend
        final responseData = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _status =
              responseData['message'] ??
              'Google Calendar Connected Successfully via Backend!';
          _errorMessage = null;
          // Potentially clear auth code and verifier now as they are used
          // _authorizationCode = null;
          // _codeVerifier = null;
          debugPrint('Backend success response: ${response.body}');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_status, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );

        // TODO: Navigate to the next screen or update UI to show connected status persistently

        if (mounted) { // Check if the widget is still in the tree
          context.read<AuthProvider>().updateUserGoogleCalendarLinkStatus(
                newAppSessionToken: "ppSessionToken", // If backend issues a new/updated app token
                isCalendarLinked: true,
                currentUserUuid: responseData['user_id'], // Pass user UUID or ID from backend
                // any other relevant data from backend
              );
        }
      } else {
        // Handle backend errors
        String errorMsg = 'Failed to connect with backend.';
        try {
          final responseBody = jsonDecode(response.body);
          errorMsg =
              responseBody['error'] ??
              responseBody['message'] ??
              'Backend error: ${response.statusCode}';
        } catch (e) {
          errorMsg =
              'Backend error: ${response.statusCode}. Invalid response format.';
          debugPrint(
            'Error decoding backend JSON response: $e. Response body: ${response.body}',
          );
        }
        setState(() {
          _isLoading = false;
          _status = 'Backend Connection Error.';
          _errorMessage = errorMsg;
        });
        debugPrint(
          'Backend error response: ${response.statusCode} - ${response.body}',
        );
        _showErrorSnackbar(_errorMessage!);
      }
    } catch (e) {
      // Handle network or other exceptions during the HTTP call
      setState(() {
        _isLoading = false;
        _status = 'Error: Failed to Send Code to Backend.';
        _errorMessage =
            'An exception occurred while communicating with the backend: ${e.toString()}';
      });
      debugPrint('Exception during backend communication: $e');
      _showErrorSnackbar(_errorMessage!);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORION - Link Google Calendar'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Connect Google Calendar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed:
                  _isLoading || backendApiBaseUrl == "YOUR_BACKEND_API_ENDPOINT"
                      ? null // Disable button if loading or not configured
                      : _handleGoogleConnect, // Pass context here
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!_isLoading &&
                (backendApiBaseUrl == "YOUR_BACKEND_API_ENDPOINT"))
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Button disabled: Configuration needed. See status/instructions.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color:
                            _errorMessage != null
                                ? Colors.redAccent
                                : (_status.contains("Successfully")
                                    ? Colors.green.shade700
                                    : Colors.black87),
                      ),
                    ),
                    if (_authorizationCode != null &&
                        !_status.contains("Successfully")) ...[
                      // Show only if not yet successful
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text(
                        "Auth Code (for backend):",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SelectableText(
                        _authorizationCode!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "PKCE Verifier (for backend):",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SelectableText(
                        _codeVerifier ?? "Not generated",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SelectableText(
                          'Details: $_errorMessage',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            _buildSetupInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupInstructions() {
    return Card(
      color: Colors.amber.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.amber.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
              ],
            ),
],
        ),
      ),
    );
  }
}
