// lib/src/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Import your AuthProvider
import 'auth_provider.dart'; // Adjust path as needed
import 'google_oauth_service.dart';
// Optional: For a dedicated Google Sign-In button style, you might use a package
// or create a custom styled button. For this example, we'll use ElevatedButton.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Local loading state specifically for the button press action,
  // to give immediate feedback, though AuthProvider.isLoading handles the overall process.
  bool _isSigningIn = false;

  // --- Step 5.4 & 5.3: Implement handleSignIn function ---
  Future<void> _handleSignIn(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_isSigningIn) return;

    setState(() {
      _isSigningIn = true;
    });

    try {
      final result = await GoogleOAuthService.signInWithGoogle(context);
      final accessToken = result['access_token'] as String?;
      final userId = result['user_id'] as String?;
      final expires = result['expires_in'] as int? ?? 0;

      if (accessToken != null && userId != null) {
        await authProvider.saveBackendAuth(
          accessToken: accessToken,
          expiresIn: expires,
          userId: userId,
        );
      }

      if (context.mounted) {
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Step 5.3: Access isLoading/error state from AuthenticationService ---
    // Use context.watch to rebuild when AuthProvider changes
    final authProvider = context.watch<AuthProvider>();

    // --- Step 5.6: Display error messages ---
    // This useEffect-like behavior can be achieved by checking authProvider.errorMessage
    // directly in the build method or using a listener if more complex UI updates are needed.
    // For simplicity, a SnackBar is shown in _handleSignIn on direct error.
    // A persistent error from AuthProvider could be shown as text.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authProvider.errorMessage != null && !_isSigningIn && ModalRoute.of(context)?.isCurrent == true) {
        // Ensure we only show snackbar if this screen is current and not during an active sign-in attempt
        // to avoid duplicate messages if error is set by both local catch and provider.
        // This is a bit tricky; often, error display is centralized or part of the authProvider state itself.
        // For now, let's assume _handleSignIn's SnackBar is the primary immediate feedback.
      }
    });


    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Step 5.2: Build the UI (Logo, Title) ---
                // Placeholder for App Logo
                const Icon(
                  Icons.calendar_today, // Example icon
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to Orion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your AI Calendar Assistant',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 60),

                // --- Step 5.5: Display CircularProgressIndicator ---
                if (authProvider.isLoading || _isSigningIn)
                  const Center(child: CircularProgressIndicator())
                else
                // --- Step 5.2 & 5.4: Google Sign-In Button ---
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login), // Replace with a Google icon if desired
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      // backgroundColor: Colors.white, // Example style
                      // foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: () => _handleSignIn(context),
                  ),

                // Display persistent error from AuthProvider
                if (authProvider.errorMessage != null && !(authProvider.isLoading || _isSigningIn))
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      'Error: ${authProvider.errorMessage}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
