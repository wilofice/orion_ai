// lib/src/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Import your AuthProvider
import 'auth_provider.dart'; // Adjust path as needed
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
    // Access the AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isLoading || _isSigningIn) return; // Prevent double taps

    setState(() {
      _isSigningIn = true;
    });

    try {
      print('LoginScreen: Initiating sign-in...');
      await authProvider.signInWithGoogle();
      // On successful sign-in, the AuthProvider's state will change,
      // and the AuthGate/RootNavigator (from FE-TASK-7) will navigate away.
      // So, no explicit navigation here.
      print('LoginScreen: signInWithGoogle call completed.');
      // If navigation doesn't happen immediately due to listener delays,
      // _isSigningIn will be reset by the widget rebuilding or unmounting.
    } catch (e) {
      // Errors are typically handled and set within AuthProvider.
      // We can show a SnackBar here for immediate feedback if AuthProvider doesn't.
      // However, it's better to rely on AuthProvider.errorMessage for consistency.
      print('LoginScreen: Error during signInWithGoogle call: $e');
      if (mounted) { // Check if the widget is still in the tree
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Sign-in failed. Please try again.'),
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
