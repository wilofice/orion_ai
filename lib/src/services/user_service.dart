import 'package:http/http.dart' as http;
import '../auth/auth_provider.dart';
import '../config.dart';

class UserService {
  final http.Client _client;
  final AuthProvider _authProvider;

  UserService({http.Client? client, required AuthProvider authProvider})
      : _client = client ?? http.Client(),
        _authProvider = authProvider;

  Future<bool> verifyToken() async {
    final token = _authProvider.backendAccessToken;
    if (token == null) return false;

    final response = await _client.get(
      Uri.parse('${AppConfig.backendApiBaseUrl}/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      },
    );

    return response.statusCode == 200;
  }
}
