import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_provider.dart';
import '../events/calendar_event.dart';
import '../events/events_response.dart';

const String _apiBaseUrl = 'http://192.168.1.22:8001/Prod';
//const String _apiBaseUrl = 'https://ww62jfo5jh.execute-api.eu-north-1.amazonaws.com/Prod';
String _eventsEndpoint(String userId) => '$_apiBaseUrl/events/$userId/upcoming';

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

  Future<EventsResponse> fetchUpcomingEvents({int days = 7, String timezone = 'UTC'}) async {
    final token = _authProvider.backendAccessToken;
    final userId = _authProvider.currentUserUuid;
    if (token == null || userId.isEmpty) {
      throw CalendarServiceError('Not authenticated', statusCode: 401);
    }
    final uri = Uri.parse(_eventsEndpoint(userId)).replace(queryParameters: {
      'days': days.toString(),
      'timezone': timezone,
    });
    try {
      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return EventsResponse.fromJson(data);
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
