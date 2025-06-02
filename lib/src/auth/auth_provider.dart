// lib/src/auth/auth_provider.dart

import 'dart:async';
import 'package:flutter/material.dart'; // For ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // Alias to avoid name clash
import 'package:google_sign_in/google_sign_in.dart';
import '../services/token_storage.dart';
// For FirebaseException
// import 'package:firebase_analytics/firebase_analytics.dart'; // For logging events

// Define a simpler User type if needed, or use fb_auth.User directly
// For this example, fb_auth.User is sufficient.
// typedef User = fb_auth.User;

class AuthProvider with ChangeNotifier {
  final fb_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  // final FirebaseAnalytics _analytics; // Optional: for logging

  final TokenStorage _tokenStorage;

  String? _backendAccessToken;
  DateTime? _backendTokenExpiry;

  fb_auth.User? _currentUser;
  bool _isLoading = true; // Start true for initial auth state check
  String? _errorMessage;
  String? _googleIdToken; // Store Google ID token if needed
  String? _googleAccessToken; // Store Google Access token if needed for direct API calls

  StreamSubscription<fb_auth.User?>? _authStateSubscription;
  
  bool _isCalendarLinked = false;
  String _currentUserUuid = '';
  bool get isCalendarLinked => _isCalendarLinked;
  String get currentUserUuid => _currentUserUuid;
  String? get backendAccessToken => _backendAccessToken;
  DateTime? get backendTokenExpiry => _backendTokenExpiry;
  AuthProvider({
    fb_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    TokenStorage? tokenStorage,
    // FirebaseAnalytics? analytics,
  })  : _firebaseAuth = firebaseAuth ?? fb_auth.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(
          // Optionally configure scopes here if needed for Google APIs directly
          // scopes: [
          //   'email',
          //   'https://www.googleapis.com/auth/calendar.readonly', // Example scope
          // ],
        )
        // _analytics = analytics ?? FirebaseAnalytics.instance
        ,
        _tokenStorage = tokenStorage ?? const TokenStorage() {
    _listenToAuthChanges();
    _loadStoredBackendToken();
  }




  // --- Getters for state ---
  fb_auth.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get googleIdToken => _googleIdToken;
  String? get googleAccessToken => _googleAccessToken;

  bool get isAuthenticated => _currentUser != null;

  // --- Step 4.5: Listen to auth state changes ---
  void _listenToAuthChanges() {
    print('AuthProvider: Setting up Firebase auth state listener...');
    _authStateSubscription = _firebaseAuth.authStateChanges().listen(
          (fb_auth.User? user) {
        print('AuthProvider: Auth state changed. User: ${user?.uid ?? 'No user'}');
        _currentUser = user;
        _googleIdToken = null; // Clear tokens on auth state change
        _googleAccessToken = null;
        if (user == null) {
          _backendAccessToken = null;
          _backendTokenExpiry = null;
          _isCalendarLinked = false;
        }

        if (_isLoading) {
          _isLoading = false; // Finished initial check
        }
        _errorMessage = null; // Clear any previous errors on auth change
        notifyListeners();
      },
      onError: (error) {
        print('AuthProvider: Auth state listener error: $error');
        _currentUser = null;
        _googleIdToken = null;
        _googleAccessToken = null;
        _backendAccessToken = null;
        _backendTokenExpiry = null;
        _isCalendarLinked = false;
        _errorMessage = "Error in authentication state: $error";
        if (_isLoading) {
          _isLoading = false;
        }
        notifyListeners();
      },
    );
  }

  Future<void> _loadStoredBackendToken() async {
    _backendAccessToken = await _tokenStorage.readAccessToken();
    _backendTokenExpiry = await _tokenStorage.readExpiry();
    _currentUserUuid = await _tokenStorage.readUserId() ?? '';
    if (_backendAccessToken != null) {
      _isCalendarLinked = true;
    }
    notifyListeners();
  }

  // --- Step 4.2: Implement signInWithGoogle ---
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    print('AuthProvider: Attempting Google Sign-In...');

    try {
      // Trigger the Google authentication flow.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        print('AuthProvider: Google Sign-In cancelled by user.');
        _errorMessage = 'Sign-in cancelled by user.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      print('AuthProvider: Google Sign-In successful, got GoogleSignInAccount.');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      _googleIdToken = googleAuth.idToken;
      _googleAccessToken = googleAuth.accessToken; // Useful for direct Google API calls
      print('AuthProvider: Retrieved Google ID and Access tokens.');

      if (googleAuth.idToken == null) {
        throw fb_auth.FirebaseAuthException(
          code: 'google-sign-in-no-id-token',
          message: 'Google Sign-In failed to return an ID token.',
        );
      }

      // Create a new Firebase credential
      final fb_auth.AuthCredential credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('AuthProvider: Created Firebase Google credential.');

      // Sign-in to Firebase with the credential
      await _firebaseAuth.signInWithCredential(credential);
      print('AuthProvider: Firebase Sign-In with Google credential successful.');

      // Log analytics event (optional)
      // await _analytics.logLogin(loginMethod: 'google');
      // print('AuthProvider: Logged login event to Firebase Analytics.');

      // Auth state listener will update _currentUser and set _isLoading = false
      // _isLoading = false; // No need to set here, listener handles it
      // _errorMessage = null; // Already cleared at the start
      // notifyListeners(); // Listener will notify

    } on fb_auth.FirebaseAuthException catch (e) {
      print('AuthProvider: FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}');
      _errorMessage = "Firebase Auth Error: ${e.message} (${e.code})";
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('AuthProvider: Generic error during Google Sign-In: $e');
      _errorMessage = 'An unexpected error occurred during sign-in: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Step 4.3: Implement signOut ---
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners(); // Show loading state immediately
    print('AuthProvider: Attempting Sign Out...');

    try {
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      print('AuthProvider: Firebase Sign Out successful.');

      // Sign out from Google (disconnects app, user has to choose account again next time)
      // Using signOut() is usually enough. disconnect() is more thorough.
      await _googleSignIn.signOut();
      // await _googleSignIn.disconnect(); // Optional: if you want to force account chooser
      print('AuthProvider: Google Sign-In Sign Out successful.');

      // Log analytics event (optional)
      // await _analytics.logEvent(name: 'logout');
      // print('AuthProvider: Logged logout event to Firebase Analytics.');

      // Auth state listener will update _currentUser to null and _isLoading = false
      _currentUser = null; // Handled by listener
      _googleIdToken = null; // Handled by listener
      _googleAccessToken = null; // Handled by listener
      _isLoading = false; // Handled by listener
      _errorMessage = null; // Handled by listener
      await clearBackendAuth(); // Reset calendar link status
      // notifyListeners(); // Listener will notify

    } catch (e) {
      print('AuthProvider: Error during Sign Out: $e');
      _errorMessage = 'Error during sign out: $e';
      _isLoading = false; // Ensure loading stops even on error
      notifyListeners();
    }
  }

// In your AuthProvider class
// bool _isGoogleCalendarLinked = false;
// bool get isGoogleCalendarLinked => _isGoogleCalendarLinked;
// String? _appSessionToken; // If your app uses its own session tokens

  void updateUserGoogleCalendarLinkStatus({String? newAppSessionToken, required bool isCalendarLinked, required String currentUserUuid}) {
      // if (newAppSessionToken != null) {
      //   _appSessionToken = newAppSessionToken;
      //   // Potentially update _isAuthenticated or other relevant flags
      // }
      // _isGoogleCalendarLinked = isCalendarLinked;
      // print("AuthProvider: Google Calendar linked status updated to $isCalendarLinked");
      // print("AuthProvider: App session token updated: $newAppSessionToken");

      // CRITICAL: Update any state that your AppRouter's redirect logic depends on.
      // For example, if linking Google Calendar also authenticates the user in your app:
      // _status = AuthenticationStatus.authenticated;
      // _user = User(id: 'some_user_id_from_backend'); // Or however you manage user state
      _isCalendarLinked = isCalendarLinked;
      _currentUserUuid = currentUserUuid;
      //notifyListeners(); // This is crucial to trigger GoRouter's refreshListenable
  }

  Future<void> saveBackendAuth({
    required String accessToken,
    required int expiresIn,
    required String userId,
  }) async {
    _backendAccessToken = accessToken;
    _backendTokenExpiry =
        DateTime.now().add(Duration(seconds: expiresIn));
    _currentUserUuid = userId;
    _isCalendarLinked = true;
    await _tokenStorage.saveToken(
        accessToken: accessToken, expiresIn: expiresIn, userId: userId);
    notifyListeners();
  }

  Future<void> clearBackendAuth() async {
    _backendAccessToken = null;
    _backendTokenExpiry = null;
    _currentUserUuid = '';
    _isCalendarLinked = false;
    await _tokenStorage.clear();
    notifyListeners();
  }
  // --- Step 4.6: Expose methods (already done by making them public) ---
  // State is exposed via getters.

  @override
  void dispose() {
    print('AuthProvider: Disposing and cancelling auth state listener.');
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
