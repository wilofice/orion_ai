// lib/src/chat/chat_provider.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart'; // For generating unique message IDs (add uuid to pubspec.yaml)

// Assuming ChatMessage, MessageSender, MessageStatus are defined in chat_message_bubble.dart or a models file
import '../ui/widgets/chat_message_bubble.dart'; // Adjust path
// Assuming ChatService and its DTOs are defined
import '../services/chat_service.dart'; // Adjust path
import '../services/audio_upload_service.dart';
import '../events/event_provider.dart';

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
  bool _historyLoaded = false;

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

  Future<void> loadLatestConversation(String userId) async {
    if (_historyLoaded || userId.isEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final sessions = await _chatService.fetchConversations(userId: userId);
      if (sessions.isNotEmpty) {
        sessions.sort((a, b) {
          final aTime = a.history.isNotEmpty ? (a.history.last.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)) : DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.history.isNotEmpty ? (b.history.last.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)) : DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        final latest = sessions.first;
        _sessionId = latest.sessionId;
        _messages = latest.history.map((t) {
          final part = t.parts.isNotEmpty ? t.parts.first : '';
          String text = '';
          String? audioUrl;
          if (part is String) {
            text = part;
          } else if (part is Map<String, dynamic>) {
            text = part['transcript'] as String? ?? '';
            audioUrl = part['audio_url'] as String?;
          } else {
            text = part.toString();
          }
          final sender = t.role == 'USER' ? MessageSender.user : MessageSender.assistant;
          return ChatMessage(
              id: 'hist-${_uuid.v4()}',
              text: text,
              audioUrl: audioUrl,
              sender: sender,
              timestamp: t.timestamp ?? DateTime.now());
        }).toList().reversed.toList();
      }
      _historyLoaded = true;
    } on ChatServiceError catch (e) {
      debugPrint('ChatProvider: Failed to load conversations - ${e.message}');
      if (e.statusCode == 401) {
        await _chatService.authProvider.clearBackendAuth();
      }
    } catch (e) {
      debugPrint('ChatProvider: Failed to load conversations - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Step 9.3: Implement sendUserMessage method ---
  Future<void> sendUserMessage(String text, String userId,
      {EventProvider? eventProvider}) async {
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
    _messages.insert(0, userMessage);
    _messages.insert(0, assistantLoadingMessage);
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
        audioUrl: null,
        clientContext: requestData.clientContext,
        userId: userId, // If ChatService.sendMessage requires userId
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
      if (e.statusCode == 401) {
        await _chatService.authProvider.clearBackendAuth();
      }
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
      if (eventProvider != null) {
        eventProvider.loadEvents();
      }
    }
  }

  // Method to clear error message, can be called by UI
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> sendAudioMessage({
    required String transcript,
    required File audioFile,
    required String userId,
    EventProvider? eventProvider,
  }) async {
    if (transcript.trim().isEmpty || _isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final String userMessageId = 'user-${_uuid.v4()}';
    final String assistantLoadingMessageId = 'assistant-loading-${_uuid.v4()}';

    // Create initial user message without audio URL
    final userMessage = ChatMessage(
      id: userMessageId,
      text: transcript.trim(),
      audioUrl: null, // Will be updated after upload
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sending, // Start as sending until upload completes
    );

    final assistantLoadingMessage = ChatMessage(
      id: assistantLoadingMessageId,
      text: '',
      sender: MessageSender.assistant,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _messages.insert(0, userMessage);
    _messages.insert(0, assistantLoadingMessage);
    notifyListeners();

    final uploadService = AudioUploadService();
    String? audioUrl;
    try {
      audioUrl = await uploadService.upload(audioFile);
      debugPrint('ChatProvider: Audio uploaded successfully to: $audioUrl');
      
      // Update user message with audio URL and sent status
      final userIndex = _messages.indexWhere((msg) => msg.id == userMessageId);
      if (userIndex != -1) {
        _messages[userIndex] = ChatMessage(
          id: userMessageId,
          text: transcript.trim(),
          audioUrl: audioUrl,
          sender: MessageSender.user,
          timestamp: _messages[userIndex].timestamp,
          status: MessageStatus.sent,
        );
        notifyListeners();
      }

      final response = await _chatService.sendMessage(
        promptText: transcript.trim(),
        sessionId: _sessionId,
        clientContext: {'audio_url': audioUrl},
        userId: userId,
        audioUrl: audioUrl,
      );

      if (response.sessionId != _sessionId) {
        _sessionId = response.sessionId;
      }

      final loadingIndex = _messages.indexWhere((msg) => msg.id == assistantLoadingMessageId);
      if (loadingIndex != -1) {
        _messages[loadingIndex] = ChatMessage(
          id: assistantLoadingMessageId,
          text: response.responseText ?? 'Sorry, I received an empty response.',
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
          status: response.status == BackendResponseStatus.completed ||
                  response.status == BackendResponseStatus.needs_clarification
              ? MessageStatus.sent
              : MessageStatus.error,
        );
      }
    } on ChatServiceError catch (e) {
      debugPrint('ChatProvider: sendAudioMessage ChatServiceError - ${e.message}');
      if (e.statusCode == 401) {
        await _chatService.authProvider.clearBackendAuth();
      }
      _errorMessage = e.message;
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
    } catch (e) {
      debugPrint('ChatProvider: sendAudioMessage error - $e');
      
      // Determine if it's an upload error or a send error
      String errorMessage = 'Failed to send audio message';
      if (audioUrl == null) {
        errorMessage = 'Failed to upload audio: ${e.toString()}';
        // Update user message to show error status
        final userIndex = _messages.indexWhere((msg) => msg.id == userMessageId);
        if (userIndex != -1) {
          _messages[userIndex] = ChatMessage(
            id: userMessageId,
            text: transcript.trim(),
            audioUrl: null,
            sender: MessageSender.user,
            timestamp: _messages[userIndex].timestamp,
            status: MessageStatus.error,
          );
        }
      }
      
      _errorMessage = errorMessage;
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
      if (eventProvider != null) {
        eventProvider.loadEvents();
      }
    }
  }
}
