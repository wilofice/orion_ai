import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import '../auth/auth_provider.dart';
import '../config.dart';

String get _chatEndpoint =>
    '${AppConfig.backendApiBaseUrl}/chat/prompt';

// --- Data Structures (Step 8.2) ---
// Matches the backend ChatRequest schema (from Task ORCH-3)

class ChatRequestData {
  final String userId; // Added here, will be populated from auth
  final String promptText;
  final String? sessionId;
  final String? audioUrl;
  final Map<String, dynamic>? clientContext;

  ChatRequestData({
    required this.userId,
    required this.promptText,
    this.sessionId,
    this.audioUrl,
    this.clientContext,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'prompt_text': promptText,
      if (sessionId != null) 'session_id': sessionId,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (clientContext != null) 'client_context': clientContext,
    };
  }
}

// Matches the backend ResponseStatus enum
enum BackendResponseStatus {
  completed,
  needs_clarification,
  error,
}

// Matches the backend ChatResponse schema
class ChatResponseData {
  final String sessionId;
  final BackendResponseStatus status;
  final String? responseText;
  final List<String>? clarificationOptions;

  ChatResponseData({
    required this.sessionId,
    required this.status,
    this.responseText,
    this.clarificationOptions,
  });

  factory ChatResponseData.fromJson(Map<String, dynamic> json) {
    var statusString = json['status'] as String?;
    BackendResponseStatus parsedStatus;
    switch (statusString) {
      case 'completed':
        parsedStatus = BackendResponseStatus.completed;
        break;
      case 'needs_clarification':
        parsedStatus = BackendResponseStatus.needs_clarification;
        break;
      case 'error':
        parsedStatus = BackendResponseStatus.error;
        break;
      default:
      // Handle unknown status, perhaps default to error or throw
        debugPrint('ChatResponseData: Unknown status received: $statusString');
        parsedStatus = BackendResponseStatus.error;
    }

    return ChatResponseData(
      sessionId: json['session_id'] as String,
      status: parsedStatus,
      responseText: json['response_text'] as String?,
      clarificationOptions: json['clarification_options'] != null
          ? List<String>.from(json['clarification_options'] as List)
          : null,
    );
  }
}

// Conversation data models for history retrieval
class ConversationTurnData {
  final String role;
  final List<dynamic> parts;
  final DateTime? timestamp;

  ConversationTurnData({required this.role, required this.parts, this.timestamp});

  factory ConversationTurnData.fromJson(Map<String, dynamic> json) {
    return ConversationTurnData(
      role: json['role'] as String? ?? '',
      parts: (json['parts'] as List<dynamic>? ?? []).toList(),
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) : null,
    );
  }
}

class ConversationData {
  final String sessionId;
  final String userId;
  final List<ConversationTurnData> history;

  ConversationData({required this.sessionId, required this.userId, required this.history});

  factory ConversationData.fromJson(Map<String, dynamic> json) {
    return ConversationData(
      sessionId: json['session_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      history: (json['history'] as List<dynamic>? ?? [])
          .map((e) => ConversationTurnData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// Matches the backend ErrorDetail schema
class ApiErrorDetail {
  final String errorCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiErrorDetail({
    required this.errorCode,
    required this.message,
    this.details,
  });

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      errorCode: json['error_code'] as String,
      message: json['message'] as String,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}

// Custom Error class for ChatService specific issues
class ChatServiceError extends Error {
  final String message;
  final int? statusCode;
  final String? errorCode; // From backend's ErrorDetail
  final Map<String, dynamic>? errorDetails; // From backend's ErrorDetail

  ChatServiceError(
      this.message, {
        this.statusCode,
        this.errorCode,
        this.errorDetails,
      });

  @override
  String toString() {
    return 'ChatServiceError: $message (Status: $statusCode, Code: $errorCode, Details: $errorDetails)';
  }
}

// --- Service Implementation (Step 8.1 & 8.3) ---
class ChatService {
  final http.Client _httpClient; // For testability
  final AuthProvider _authProvider;

  ChatService({
    http.Client? httpClient, // Allow injecting for tests
    required AuthProvider authProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _authProvider = authProvider;

  AuthProvider get authProvider => _authProvider;

  Future<ChatResponseData> sendMessage({
    required String promptText,
    String? sessionId,
    String? audioUrl,
    Map<String, dynamic>? clientContext,
    required String userId,
  }) async {
    debugPrint('ChatService: Preparing to send message...');

    final token = _authProvider.backendAccessToken;
    if (token == null) {
      throw ChatServiceError('Not authenticated with backend.',
          statusCode: 401, errorCode: 'NO_BACKEND_TOKEN');
    }

    // 2. Prepare the full request body
    final requestData = ChatRequestData(
      userId: userId,
      promptText: promptText,
      sessionId: sessionId,
      audioUrl: audioUrl,
      clientContext: clientContext,
    );

    debugPrint('ChatService: Sending POST to $_chatEndpoint with body: ${jsonEncode(requestData.toJson())}');

    // 3. Make the POST request using http client
    try {
      final response = await _httpClient.post(
        Uri.parse(_chatEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
        body: jsonEncode(requestData.toJson()),
      );

      debugPrint('ChatService: Received response status: ${response.statusCode}');
      debugPrint('ChatService: Response body: ${response.body}');


      // 4. Handle response status
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 5. Parse successful JSON response
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        debugPrint('ChatService: Successfully parsed response data.');
        return ChatResponseData.fromJson(responseBody);
      } else {
        // 6. Handle error response (non-2xx status)
        ApiErrorDetail? errorDetail;
        String errorMessage = 'Request failed with status ${response.statusCode}';
        try {
          final Map<String, dynamic> errorBody = jsonDecode(response.body);
          errorDetail = ApiErrorDetail.fromJson(errorBody);
          errorMessage = errorDetail.message;
          debugPrint('ChatService: Parsed error response: $errorDetail');
        } catch (e) {
          debugPrint('ChatService: Could not parse error JSON body. Using status text: ${response.reasonPhrase}');
          errorMessage = response.reasonPhrase ?? errorMessage;
        }
        throw ChatServiceError(
          errorMessage,
          statusCode: response.statusCode,
          errorCode: errorDetail?.errorCode,
          errorDetails: errorDetail?.details,
        );
      }
    } on http.ClientException catch (e) { // Catches socket exceptions, etc.
      debugPrint('ChatService: HTTP ClientException (Network error): $e');
      throw ChatServiceError('Network request failed: ${e.message}', errorCode: 'NETWORK_ERROR');
    } catch (e) {
      // 7. Handle other errors (e.g., JSON parsing of success response, unexpected)
      debugPrint('ChatService: Unexpected error during sendMessage: $e');
      if (e is ChatServiceError) {
        rethrow; // Re-throw ChatServiceErrors directly
      }
      throw ChatServiceError('An unexpected error occurred: ${e.toString()}', errorCode: 'UNEXPECTED_ERROR');
    }
  }

  Future<List<ConversationData>> fetchConversations({required String userId}) async {
    final token = _authProvider.backendAccessToken;
    if (token == null) {
      throw ChatServiceError('Not authenticated with backend.',
          statusCode: 401, errorCode: 'NO_BACKEND_TOKEN');
    }

    final url = '${AppConfig.backendApiBaseUrl}/conversations/$userId';
    try {
      final response = await _httpClient.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json'
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => ConversationData.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        ApiErrorDetail? errorDetail;
        String errorMessage = 'Request failed with status ${response.statusCode}';
        try {
          final Map<String, dynamic> errorBody = jsonDecode(response.body);
          errorDetail = ApiErrorDetail.fromJson(errorBody);
          errorMessage = errorDetail.message;
        } catch (_) {}
        throw ChatServiceError(errorMessage,
            statusCode: response.statusCode, errorCode: errorDetail?.errorCode);
      }
    } on http.ClientException catch (e) {
      throw ChatServiceError('Network request failed: ${e.message}',
          errorCode: 'NETWORK_ERROR');
    } catch (e) {
      if (e is ChatServiceError) rethrow;
      throw ChatServiceError('An unexpected error occurred: ${e.toString()}',
          errorCode: 'UNEXPECTED_ERROR');
    }
  }
}