import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_provider.dart';
import '../events/calendar_event.dart';

const String _apiBaseUrl = 'https://ww62jfo5jh.execute-api.eu-north-1.amazonaws.com/Prod';
const String _eventsEndpoint = _apiBaseUrl + '/events';

class CalendarServiceError extends Error {
  final String message;
  final int? statusCode;
  CalendarServiceError(this.message, {this.statusCode});
  @override
  String toString() => 'CalendarServiceError: $message';
}

class CalendarService {
  final http.Client _client;
  final AuthProvider _authProvider;

  CalendarService({http.Client? client, required AuthProvider authProvider})
      : _client = client ?? http.Client(),
        _authProvider = authProvider;

  Future<List<CalendarEvent>> fetchEvents() async {
    final token = _authProvider.backendAccessToken;
    if (token == null) {
      throw CalendarServiceError('Not authenticated', statusCode: 401);
    }
    try {
      final response = await _client.get(
        Uri.parse(_eventsEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw CalendarServiceError('Request failed',
            statusCode: response.statusCode);
      }
    } on http.ClientException catch (e) {
      throw CalendarServiceError('Network error: ${e.message}');
    } catch (e) {
      if (e is CalendarServiceError) rethrow;
      throw CalendarServiceError('Unexpected error: $e');
    }
  }
}
