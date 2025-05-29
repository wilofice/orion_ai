import 'package:flutter/material.dart';
import '../services/preference_service.dart';
import '../services/connectivity_service.dart';
import 'user_preferences.dart';

class PreferencesProvider with ChangeNotifier {
  final PreferenceService _preferenceService;
  final ConnectivityService _connectivityService;

  UserPreferences? _preferences;
  bool _isLoading = false;

  PreferencesProvider({
    required PreferenceService preferenceService,
    required ConnectivityService connectivityService,
  })  : _preferenceService = preferenceService,
        _connectivityService = connectivityService;

  UserPreferences? get preferences => _preferences;
  bool get isLoading => _isLoading;

  Future<void> loadPreferences() async {
    _isLoading = true;
    notifyListeners();
    _preferences = await _preferenceService.getPreferences();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updatePreferences(UserPreferences prefs) async {
    _preferences = prefs;
    notifyListeners();
    await _preferenceService.savePreferences(prefs);
  }
}
