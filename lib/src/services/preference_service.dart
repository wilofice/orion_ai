import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_provider.dart';
import '../preferences/user_preferences.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

const String _apiBaseUrl = 'http://192.168.1.22:8001/Prod';
//const String _apiBaseUrl = 'https://ww62jfo5jh.execute-api.eu-north-1.amazonaws.com/Prod';
String _prefsEndpoint(String userId) => '$_apiBaseUrl/preferences/$userId';
const String _cacheKey = 'userPreferences';

class PreferenceService {
  final CacheService _cacheService;
  final ConnectivityService _connectivityService;
  final AuthProvider _authProvider;
  final http.Client _client;

  PreferenceService({
    required CacheService cacheService,
    required ConnectivityService connectivityService,
    required AuthProvider authProvider,
    http.Client? client,
  })  : _cacheService = cacheService,
        _connectivityService = connectivityService,
        _authProvider = authProvider,
        _client = client ?? http.Client();

  Future<UserPreferences> getPreferences() async {
    final cached = await _cacheService.getObject(_cacheKey);
    if (!_connectivityService.isOnline && cached != null) {
      return UserPreferences.fromJson(cached);
    }

    final token = _authProvider.backendAccessToken;
    final userId = _authProvider.currentUserUuid;
    if (token == null || userId.isEmpty) {
      return cached != null
          ? UserPreferences.fromJson(cached)
          : UserPreferences(
              userId: userId,
              timeZone: '',
              workingHours: const {},
              preferredMeetingTimes: const [],
              daysOff: const [],
              preferredBreakDurationMinutes: 0,
              workBlockMaxDurationMinutes: 0,
              createdAt: 0,
              updatedAt: 0,
            );
    }

    try {
      final response = await _client.get(Uri.parse(_prefsEndpoint(userId)), headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      });
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _cacheService.saveObject(_cacheKey, data);
        return UserPreferences.fromJson(data);
      }
    } catch (_) {}

    return cached != null
        ? UserPreferences.fromJson(cached)
        : UserPreferences(darkMode: false);
  }

  Future<void> savePreferences(UserPreferences prefs) async {
    await _cacheService.saveObject(_cacheKey, prefs.toJson());
    final token = _authProvider.backendAccessToken;
    final userId = _authProvider.currentUserUuid;
    if (token == null || !_connectivityService.isOnline || userId.isEmpty) {
      return;
    }
    try {
      await _client.post(
        Uri.parse(_prefsEndpoint(userId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(prefs.toBackendJson()),
      );
    } catch (_) {}
  }
}
