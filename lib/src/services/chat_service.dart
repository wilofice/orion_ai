import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

// --- Configuration ---
// Replace with your actual backend API URL
// Use environment variables or a config file in a real application
const String _apiBaseUrl = 'https://ww62jfo5jh.execute-api.eu-north-1.amazonaws.com/Prod'; // Replace with your production URL

const String _chatEndpoint = '$_apiBaseUrl/v1/chat/prompt';

// --- Data Structures (Step 8.2) ---
// Matches the backend ChatRequest schema (from Task ORCH-3)
class ChatRequestData {
  final String userId; // Added here, will be populated from auth
  final String promptText;
  final String? sessionId;
  final Map<String, dynamic>? clientContext;

  ChatRequestData({
    required this.userId,
    required this.promptText,
    this.sessionId,
    this.clientContext,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'prompt_text': promptText,
      if (sessionId != null) 'session_id': sessionId,
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
  final fb_auth.FirebaseAuth _firebaseAuth;
  final http.Client _httpClient; // For testability

  ChatService({
    fb_auth.FirebaseAuth? firebaseAuth,
    http.Client? httpClient, // Allow injecting for tests
  })  : _firebaseAuth = firebaseAuth ?? fb_auth.FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client();

  Future<ChatResponseData> sendMessage({
    required String promptText,
    String? sessionId,
    Map<String, dynamic>? clientContext,
  }) async {
    debugPrint('ChatService: Preparing to send message...');

    // 1. Get current user and Firebase ID token
    final fb_auth.User? currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      debugPrint('ChatService Error: No authenticated user found.');
      throw ChatServiceError('User not authenticated. Please sign in.',
          statusCode: 401, errorCode: 'NOT_AUTHENTICATED');
    }

    String? idToken;
    try {
      idToken = await currentUser.getIdToken(false); // forceRefresh: false
      debugPrint('ChatService: Got Firebase ID token.');
    } catch (e) {
      debugPrint('ChatService Error: Failed to get Firebase ID token: $e');
      throw ChatServiceError(
          'Failed to get authentication token: ${e.toString()}',
          statusCode: 401,
          errorCode: 'TOKEN_FETCH_FAILED');
    }

    var user_auth = 'user_from_apple';
    // 2. Prepare the full request body
    final requestData = ChatRequestData(
      //userId: currentUser.uid,
      userId: user_auth,
      promptText: promptText,
      sessionId: sessionId,
      clientContext: clientContext,
    );

    debugPrint('ChatService: Sending POST to $_chatEndpoint with body: ${jsonEncode(requestData.toJson())}');

    // 3. Make the POST request using http client
    try {
      final response = await _httpClient.post(
        Uri.parse(_chatEndpoint),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer apple',
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
}

// --- Example Usage (Conceptual - Call this from ChatManager/Provider) ---
/*
Future<void> exampleSendMessage(BuildContext context, String prompt) async {
  // Assuming ChatService is provided via Provider or accessible globally
  // final chatService = Provider.of<ChatService>(context, listen: false);
  final chatService = ChatService(); // For standalone example

  try {
    final response = await chatService.sendMessage(
      promptText: prompt,
      sessionId: "some-session-id-123", // Manage this in your chat state
    );
    debugPrint('Chat Response Received:');
    debugPrint('  Session ID: ${response.sessionId}');
    debugPrint('  Status: ${response.status}');
    debugPrint('  Text: ${response.responseText}');
    debugPrint('  Clarifications: ${response.clarificationOptions}');
    // Update UI based on response
  } on ChatServiceError catch (e) {
    debugPrint('Chat Service Error:');
    debugPrint('  Message: ${e.message}');
    debugPrint('  Status Code: ${e.statusCode}');
    debugPrint('  Error Code: ${e.errorCode}');
    debugPrint('  Details: ${e.errorDetails}');
    // Show specific error message to user
  } catch (e) {
    debugPrint('An unexpected error occurred: $e');
    // Show generic error message
  }
}
*/
