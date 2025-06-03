import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get backendApiBaseUrl => dotenv.env['BACKEND_API_BASE_URL'] ?? '';

  static String get awsRegion => dotenv.env['AWS_S3_REGION'] ?? 'us-east-1';
  static String get awsBucket => dotenv.env['AWS_S3_BUCKET'] ?? '';
  static String get awsAccessKey => dotenv.env['AWS_ACCESS_KEY'] ?? '';
  static String get awsSecretKey => dotenv.env['AWS_SECRET_KEY'] ?? '';

  static String get googleCustomSchemeIos =>
      dotenv.env['GOOGLE_CUSTOM_SCHEME_IOS'] ?? '';
  static String get googleCustomSchemeAndroid =>
      dotenv.env['GOOGLE_CUSTOM_SCHEME_ANDROID'] ?? '';
}
