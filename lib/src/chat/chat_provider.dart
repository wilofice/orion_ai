// lib/src/chat/chat_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // For generating unique message IDs (add uuid to pubspec.yaml)

// Assuming ChatMessage, MessageSender, MessageStatus are defined in chat_message_bubble.dart or a models file
import '../ui/widgets/chat_message_bubble.dart'; // Adjust path
// Assuming ChatService and its DTOs are defined
import '../services/chat_service.dart'; // Adjust path

var _uuid = const Uuid(); // For generating unique IDs

class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  // Optional: AuthProvider can be passed if direct access to user is needed,
  // or userId can be passed to methods.
  // final AuthProvider _authProvider;

  // --- Step 9.2: Define state ---
  List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _isLoading = false;
  String? _errorMessage;

  // --- Getters for state ---
  List<ChatMessage> get messages => List.unmodifiable(_messages); // Return unmodifiable list
  String? get sessionId => _sessionId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ChatProvider({
    required ChatService chatService,
    // required AuthProvider authProvider, // If injecting AuthProvider
  }) : _chatService = chatService
  // _authProvider = authProvider
  {
    // Add initial welcome message
    _messages.add(ChatMessage(
        id: 'assistant-welcome-${_uuid.v4()}',
        text: 'Hello! How can I assist with your schedule today?',
        sender: MessageSender.assistant,
        timestamp: DateTime.now()));
    // Note: notifyListeners() might be needed here if this is done after initial build
  }

  // --- Step 9.3: Implement sendUserMessage method ---
  Future<void> sendUserMessage(String text, String userId) async {
    if (text.trim().isEmpty || _isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null; // Clear previous errors
    notifyListeners();

    final String userMessageId = 'user-${_uuid.v4()}';
    final String assistantLoadingMessageId = 'assistant-loading-${_uuid.v4()}';

    final userMessage = ChatMessage(
      id: userMessageId,
      text: text.trim(),
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sent, // User message is considered sent immediately by UI
    );

    final assistantLoadingMessage = ChatMessage(
      id: assistantLoadingMessageId,
      text: '', // Placeholder for loading
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Add user message and loading bubble to the start of the list (for reversed view)
    _messages.insert(0, assistantLoadingMessage);
    _messages.insert(0, userMessage);
    notifyListeners();

    try {
      final requestData = ChatRequestData(
        userId: userId, // Get userId from AuthProvider or pass as argument
        promptText: text.trim(),
        sessionId: _sessionId,
        // clientContext: {}, // Add any client context if needed
      );

      final response = await _chatService.sendMessage(
        promptText: requestData.promptText,
        sessionId: requestData.sessionId,
        clientContext: requestData.clientContext,
        // Note: ChatService internally gets userId from FirebaseAuth.instance.currentUser
        // So, passing userId to ChatService.sendMessage might be redundant if it's designed that way.
        // For this example, we assume ChatService's sendMessage expects prompt, sessionId, clientContext.
      );

      // Update session ID from response
      if (response.sessionId != _sessionId) {
        _sessionId = response.sessionId;
      }

      // Find the loading message and update it with the actual response
      final loadingIndex = _messages.indexWhere((msg) => msg.id == assistantLoadingMessageId);
      if (loadingIndex != -1) {
        _messages[loadingIndex] = ChatMessage(
          id: assistantLoadingMessageId, // Keep the same ID
          text: response.responseText ?? 'Sorry, I received an empty response.',
          sender: MessageSender.assistant,
          timestamp: DateTime.now(), // Update timestamp to response time
          status: response.status == BackendResponseStatus.completed || response.status == BackendResponseStatus.needs_clarification
              ? MessageStatus.sent
              : MessageStatus.error, // If backend indicates error status
        );
      } else {
        // Should not happen if IDs are managed correctly
        debugPrint("ChatProvider: Could not find loading message to update.");
        // Add as a new message if not found
        _messages.insert(0, ChatMessage(
          id: 'assistant-response-${_uuid.v4()}',
          text: response.responseText ?? 'Sorry, I received an empty response.',
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
        ));
      }

      // Handle clarification or backend error status if needed
      if (response.status == BackendResponseStatus.error) {
        _errorMessage = response.responseText ?? "An error occurred with the AI assistant.";
      } else if (response.status == BackendResponseStatus.needs_clarification) {
        // UI could use response.clarificationOptions
        _errorMessage = "Clarification needed: ${response.responseText}";
      }


    } on ChatServiceError catch (e) {
      debugPrint('ChatProvider: ChatServiceError - ${e.message}');
      _errorMessage = e.message;
      // Update the loading message to show error status
      final loadingIndex = _messages.indexWhere((msg) => msg.id == assistantLoadingMessageId);
      if (loadingIndex != -1) {
        _messages[loadingIndex] = ChatMessage(
          id: assistantLoadingMessageId,
          text: '', // Or a generic error message
          sender: MessageSender.assistant,
          timestamp: _messages[loadingIndex].timestamp, // Keep original timestamp
          status: MessageStatus.error,
        );
      }
    } catch (e) {
      debugPrint('ChatProvider: Unexpected error - ${e.toString()}');
      _errorMessage = 'An unexpected error occurred. Please try again.';
      final loadingIndex = _messages.indexWhere((msg) => msg.id == assistantLoadingMessageId);
      if (loadingIndex != -1) {
        _messages[loadingIndex] = ChatMessage(
          id: assistantLoadingMessageId,
          text: '',
          sender: MessageSender.assistant,
          timestamp: _messages[loadingIndex].timestamp,
          status: MessageStatus.error,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to clear error message, can be called by UI
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
