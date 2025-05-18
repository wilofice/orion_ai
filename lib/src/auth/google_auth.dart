import 'dart:convert'; // For base64 encoding
import 'dart:math'; // For random string generation
import 'package:crypto/crypto.dart'; // For SHA256
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart'; // For web authentication
// import 'package:http/http.dart' as http; // Will be used for backend API calls
// import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For app's own session tokens

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

  // --- Configuration (MUST BE REPLACED) ---
  // IMPORTANT: Use the Client ID for "Web application" type from Google Cloud Console,
  // as your backend will securely handle the client secret.
  static const String googleClientId = "YOUR_GOOGLE_CLIENT_ID"; // <<<< REPLACE THIS
  // This is your app's unique identifier for the callback.
  // It MUST be unique and registered with Google and your app's platform settings.
  static const String customUriScheme = "com.yourapp.orion"; // <<<< REPLACE THIS (e.g., com.yourcompany.orion)
  // The redirect URI is composed of your custom URI scheme and a host/path.
  // This exact URI must be registered in your Google Cloud Console OAuth client settings.
  static const String redirectUri = "$customUriScheme:/oauth2redirect"; // Example: com.yourcompany.orion:/oauth2redirect

  // Scopes determine the level of access you're requesting.
  static const List<String> googleScopes = [
    'openid', // Requests an ID token for user identification
    'email', // Requests the user's primary email address
    'profile', // Requests basic profile information
    'https://www.googleapis.com/auth/calendar', // Full access to manage calendars and events
    // Consider more granular scopes if full access is not needed, e.g.:
    // 'https://www.googleapis.com/auth/calendar.events', // Create/edit/delete events
    // 'https://www.googleapis.com/auth/calendar.readonly', // Read-only access to calendars and events
  ];
  // --- End Configuration ---

  @override
  void initState() {
    super.initState();
    // Initial check for placeholder values
    if (googleClientId == "YOUR_GOOGLE_CLIENT_ID" || customUriScheme == "com.yourapp.orion") {
      _status = 'Configuration Required!';
      _errorMessage = 'Please update `googleClientId` and `customUriScheme` in `google_auth_screen.dart` with your actual values. Also, ensure platform configurations (AndroidManifest.xml/Info.plist) are set up for the custom URI scheme.';
    } else {
       _status = 'Ready to Connect.';
    }
  }

  // Generates a cryptographically secure random string for PKCE code_verifier and state.
  String _generateRandomString(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    // Base64 URL encoding is safe for use in URLs and does not include padding.
    return base64Url.encode(values).replaceAll('=', '');
  }

  // Generates the PKCE code_verifier.
  void _generateCodeVerifier() {
    // A common length for the verifier is 32 bytes, which results in a 43-character
    // base64url-encoded string. It must be between 43 and 128 characters.
    _codeVerifier = _generateRandomString(32);
    debugPrint("Generated PKCE Code Verifier (keep this secret until exchange): $_codeVerifier");
  }

  // Generates the PKCE code_challenge from the code_verifier (SHA256 then Base64Url encoded).
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier); // Convert verifier string to UTF-8 bytes
    final digest = sha256.convert(bytes); // Hash the bytes using SHA-256
    // Base64 URL-encode the hash and remove any padding characters ('=').
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // Initiates the Google Sign-In flow to get an authorization code.
  Future<void> _handleGoogleConnect() async {
    setState(() {
      _status = 'Initiating Connection...';
      _errorMessage = null;
      _authorizationCode = null;
    });

    // Critical configuration check before proceeding
    if (googleClientId == "YOUR_GOOGLE_CLIENT_ID") {
       setState(() {
        _status = 'Configuration Error';
        _errorMessage = 'CRITICAL: Google Client ID is not set. Please replace "YOUR_GOOGLE_CLIENT_ID" in `google_auth_screen.dart` with your actual Google OAuth Client ID for web applications.';
      });
      _showErrorSnackbar(_errorMessage!);
      return;
    }
     if (customUriScheme == "com.yourapp.orion" || !redirectUri.startsWith(customUriScheme)) {
       setState(() {
        _status = 'Configuration Error';
        _errorMessage = 'CRITICAL: Custom URI Scheme (`customUriScheme`) is not correctly set or `redirectUri` does not use it. Please replace "com.yourapp.orion" with your unique scheme and ensure it\'s configured in AndroidManifest.xml & Info.plist.';
      });
      _showErrorSnackbar(_errorMessage!);
      return;
    }

    _generateCodeVerifier(); // Generate a new verifier for each authentication attempt.
    if (_codeVerifier == null) {
      setState(() {
        _status = 'Error: PKCE Verifier Generation Failed.';
        _errorMessage = 'Could not generate the PKCE code verifier. This is an unexpected internal error.';
      });
      _showErrorSnackbar(_errorMessage!);
      return;
    }

    final String codeChallenge = _generateCodeChallenge(_codeVerifier!);
    final String state = _generateRandomString(16); // Generate a unique 'state' string for CSRF protection.

    // Construct the Google OAuth 2.0 Authorization URL.
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': googleClientId,
      'response_type': 'code', // We are requesting an authorization code.
      'redirect_uri': redirectUri, // The URI Google will redirect to after authentication.
      'scope': googleScopes.join(' '), // Space-separated list of requested scopes.
      'code_challenge': codeChallenge, // The PKCE code challenge.
      'code_challenge_method': 'S256', // Method used for PKCE challenge (SHA-256).
      'state': state, // CSRF protection token.
      'access_type': 'offline', // Request a refresh token for long-term access by the backend.
      'prompt': 'consent', // Optional: forces the consent screen to be shown every time.
                           // Useful for testing. Consider removing or changing to 'select_account' for production
                           // if the user has already granted consent to avoid redundant prompts.
    });

    debugPrint("Attempting to authenticate with URL: $authUrl");

    try {
      // Launch the web authentication flow using flutter_web_auth_2.
      // This will open a web view (iOS) or custom tab (Android) for the user to authenticate.
      final resultUrlString = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: customUriScheme, // The scheme part of your redirect_uri.
      );

      debugPrint("Authentication Result URL: $resultUrlString");

      // Parse the result URL to extract the authorization code and state.
      final Uri resultUri = Uri.parse(resultUrlString);
      final returnedState = resultUri.queryParameters['state'];

      // CRITICAL: Verify the 'state' parameter to prevent CSRF attacks.
      if (returnedState != state) {
        setState(() {
          _status = 'Error: Invalid State Parameter.';
          _errorMessage = 'The state parameter from the authentication response does not match the original state. This could indicate a Cross-Site Request Forgery (CSRF) attack. Authentication aborted.';
        });
        debugPrint("Error: State mismatch. Original state: $state, Returned state: $returnedState");
        _showErrorSnackbar(_errorMessage!);
        return;
      }

      _authorizationCode = resultUri.queryParameters['code'];
      final error = resultUri.queryParameters['error'];

      if (_authorizationCode != null && _authorizationCode!.isNotEmpty) {
        setState(() {
          _status = 'Authorization Code Received!';
          _errorMessage = null; // Clear previous errors
          debugPrint('Authorization Code: $_authorizationCode');
          debugPrint('PKCE Verifier (to be sent to backend): $_codeVerifier');
          // --- TODO: NEXT STEP (Task 1.5) ---
          // Send _authorizationCode and _codeVerifier to your backend.
          // This is where you would call a method like:
          // _sendCodeAndVerifierToBackend(_authorizationCode!, _codeVerifier!);
        });
      } else if (error != null) {
         // Handle errors returned by Google (e.g., access_denied, user_cancelled_login)
        final errorDescription = resultUri.queryParameters['error_description'] ?? 'No additional details provided by Google.';
        setState(() {
          _status = 'Authentication Error from Google.';
          _errorMessage = 'Google authentication failed: "$error". Description: "$errorDescription"';
          debugPrint('Google authentication error: $error. Description: $errorDescription. URI: $resultUri');
        });
        _showErrorSnackbar(_errorMessage!);
      } else {
        // This case should ideally not be reached if Google's flow is correct and state is verified.
        setState(() {
          _status = 'Error: Authentication Failed Unexpectedly.';
          _errorMessage = 'The authorization code was not found in the response from Google, and no explicit error was returned. The authentication process may have been cancelled or failed unexpectedly.';
          debugPrint('Authentication failed. No code or error in response URI: $resultUri');
        });
        _showErrorSnackbar(_errorMessage!);
      }
    } catch (e) {
      // Handle exceptions from flutter_web_auth_2 (e.g., user cancelled, network issues)
      setState(() {
        _status = 'Error: Authentication Exception.';
        _errorMessage = 'An exception occurred during the authentication process: ${e.toString()}';
        debugPrint('Authentication exception: $e');
      });
      _showErrorSnackbar(_errorMessage!);
    }
  }

  // Placeholder for the function that will send the authorization code and
  // PKCE verifier to your backend server. This will be implemented in Task 1.5.
  // Future<void> _sendCodeAndVerifierToBackend(String authCode, String codeVerifier) async {
  //   setState(() {
  //     _status = 'Sending code to backend...';
  //   });
  //
  //   // final backendUrl = Uri.parse('YOUR_BACKEND_API_ENDPOINT/api/auth/google/connect');
  //   // try {
  //   //   final response = await http.post(
  //   //     backendUrl,
  //   //     headers: {
  //   //       'Content-Type': 'application/json; charset=UTF-8',
  //   //       // 'Authorization': 'Bearer YOUR_APP_SESSION_TOKEN', // If your backend requires app session auth
  //   //     },
  //   //     body: jsonEncode({
  //   //       'authorization_code': authCode,
  //   //       'code_verifier': codeVerifier,
  //   //       'redirect_uri': redirectUri, // Backend needs this for validation with Google
  //   //     }),
  //   //   );
  //   //   if (response.statusCode == 200) {
  //   //     setState(() { _status = 'Google Calendar Connected Successfully via Backend!'; _errorMessage = null; });
  //   //     // TODO: Navigate or update UI to reflect connected status
  //   //   } else {
  //   //     final responseBody = jsonDecode(response.body);
  //   //     setState(() { _status = 'Backend Error: ${response.statusCode}'; _errorMessage = responseBody['error'] ?? 'Failed to connect with backend.'; });
  //   //   }
  //   // } catch (e) {
  //   //   setState(() { _status = 'Error: Failed to Send Code to Backend.'; _errorMessage = e.toString(); });
  //   // }
  //
  //   // Simulate backend call for now
  //   await Future.delayed(const Duration(seconds: 1));
  //   debugPrint("Simulated: Sent authCode '$authCode' and codeVerifier '$codeVerifier' to backend.");
  //   setState(() {
  //      _status = 'Code & Verifier ready for backend (simulated).';
  //   });
  // }

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
              icon: const Icon(Icons.link), // Or a Google icon if available
              label: const Text('Connect Google Calendar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4), // Google Blue
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
              onPressed: (googleClientId == "YOUR_GOOGLE_CLIENT_ID" || customUriScheme == "com.yourapp.orion")
                ? null // Disable button if not configured
                : _handleGoogleConnect,
            ),
            if (googleClientId == "YOUR_GOOGLE_CLIENT_ID" || customUriScheme == "com.yourapp.orion")
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Button disabled: Configuration needed. See status below.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText( // Made status selectable for easier debugging
                      _status,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _errorMessage != null ? Colors.redAccent : (_authorizationCode != null ? Colors.green.shade700 : Colors.black87),
                      ),
                    ),
                    if (_authorizationCode != null) ...[
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      Text("Authorization Code:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      SelectableText(
                        _authorizationCode!,
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      Text("PKCE Verifier:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      SelectableText(
                        _codeVerifier ?? "Not generated yet",
                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          "These values will be sent to your backend.",
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                    if (_errorMessage != null && _authorizationCode == null) // Show error details only if no auth code
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: SelectableText(
                          'Details: $_errorMessage',
                          style: const TextStyle(fontSize: 14, color: Colors.redAccent),
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

  // Helper widget for setup instructions
  Widget _buildSetupInstructions() {
    return Card(
      color: Colors.amber.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.amber.shade200)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                SizedBox(width: 8),
                Text(
                  "Important Setup Steps",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.orangeAccent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _instructionText(
              "1. Replace 'YOUR_GOOGLE_CLIENT_ID' in `google_auth_screen.dart` with your actual Google OAuth Client ID (must be type: 'Web application' as backend handles the secret).",
            ),
            _instructionText(
              "2. Replace 'com.yourapp.orion' (the `customUriScheme`) with YOUR unique custom URI scheme throughout the file. This is critical for the redirect.",
            ),
            _instructionText(
              "3. Ensure the full '$redirectUri' is registered as an 'Authorized redirect URI' in your Google Cloud Console for the Client ID used in step 1.",
            ),
            _instructionText(
              "4. Configure your Flutter app for deep linking / custom URI schemes:",
              isBold: true,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _instructionText("a. Android: Update `android/app/src/main/AndroidManifest.xml`."),
                  _instructionText("b. iOS: Update `ios/Runner/Info.plist`."),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: const Text("Android Example"),
                  onPressed: () => _showInfoDialog(context, "AndroidManifest.xml Example", _androidManifestExample),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                ),
                ElevatedButton(
                  child: const Text("iOS Example"),
                  onPressed: () => _showInfoDialog(context, "Info.plist Example", _infoPlistExample),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _instructionText(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }

  // Helper to show an AlertDialog with informational content (platform setup examples).
  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(content, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  // Example content for AndroidManifest.xml configuration.
  static const String _androidManifestExample = """


<activity
    android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    android:exported="true">
    <intent-filter android:label="flutter_web_auth_2">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.yourapp.orion" /> 
    </intent-filter>
</activity>

""";

  // Example content for Info.plist configuration.
  static const String _infoPlistExample = """
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.yourapp.orion</string> 
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourapp.orion</string>
        </array>
    </dict>
</array>
""";
    }