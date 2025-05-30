import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get backendApiBaseUrl => dotenv.env['BACKEND_API_BASE_URL'] ?? '';
}
