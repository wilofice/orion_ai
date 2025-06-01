// lib/src/chat/chat_screen.dart

import 'package:flutter/material.dart';
import '/src/ui/widgets/chat_message_bubble.dart'; // Adjust path
import '/src/ui/widgets/message_input_bar.dart'; // Adjust path
import '/src/chat/chat_provider.dart'; // Adjust path
import '/src/auth/auth_provider.dart'; // Adjust path for user ID
import '/src/events/event_provider.dart';
import '/src/services/speech_service.dart';
import '/src/services/audio_recorder_service.dart';
import '/src/preferences/preferences_provider.dart';
import '/src/preferences/user_preferences.dart';
import 'dart:io';
import 'package:provider/provider.dart';
// Import ChatMessage model if it's defined separately, otherwise it's in chat_message_bubble.dart
// from 'package:orion_app/src/models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isErrorSnackbarShown = false;
  late SpeechService _speechService;
  late AudioRecorderService _recorder;


  @override
  void initState() {
    super.initState();
    _speechService = SpeechService();
    _recorder = AudioRecorderService();
    // Initial scroll if there are messages (e.g., welcome message from ChatProvider)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUserUuid.isNotEmpty) {
        context.read<ChatProvider>().loadLatestConversation(auth.currentUserUuid);
      }
      _scrollToBottom(animate: false);
    });
  }

  void _scrollToBottom({bool animate = true}) {
    // Ensure controller is attached and there's content to scroll.
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0.0) {
      // Delay slightly to allow list to render before scrolling, especially on new messages.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) { // Check again in case widget disposed
          _scrollController.animateTo(
            // For a reversed list, scrolling to 0.0 scrolls to the "end"
            // which is visually the bottom (where new messages appear).
            _scrollController.position.minScrollExtent, // This is 0.0 for a reversed list's bottom
            duration: Duration(milliseconds: animate ? 300 : 1), // Faster if not animated
            curve: Curves.easeOut,
          );
        }
      });
    } else if (_scrollController.hasClients && _scrollController.position.maxScrollExtent == 0.0) {
      // If maxScrollExtent is 0, it means content fits, but still ensure it's at the "bottom" (offset 0 for reversed)
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      });
    }
  }

  void _handleSendPressed() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final eventProvider = Provider.of<EventProvider>(context, listen: false);

    if (authProvider.currentUserUuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to send messages.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    // Clear previous error message before sending a new one
    if (chatProvider.errorMessage != null) {
      chatProvider.clearError();
    }
    _isErrorSnackbarShown = false; // Reset snackbar flag

    // Call ChatProvider to handle sending the message
    chatProvider.sendUserMessage(text, authProvider.currentUserUuid,
        eventProvider: eventProvider);
    //chatProvider.sendUserMessage(text, authProvider.currentUser!.uid);

    _textController.clear();
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    // Scrolling will be triggered by the list update in the build method's postFrameCallback
  }

  Future<void> _handleMicPressed() async {
    await _recorder.start();
    final text = await _speechService.listenOnce();
    final recordedPath = await _recorder.stop();
    if (text == null || text.trim().isEmpty || recordedPath == null) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final eventProvider = Provider.of<EventProvider>(context, listen: false);

    if (authProvider.currentUserUuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to send messages.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    chatProvider.sendAudioMessage(
      transcript: text.trim(),
      audioFile: File(recordedPath),
      userId: authProvider.currentUserUuid,
      eventProvider: eventProvider,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speechService.stop();
    _recorder.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final prefs = context.watch<PreferencesProvider>().preferences;
    final inputMode = prefs?.inputMode ?? InputMode.text;
    final buttonPosition = prefs?.voiceButtonPosition ?? VoiceButtonPosition.right;

    final messages = chatProvider.messages;
    final isLoadingFromChatProvider = chatProvider.isLoading;
    final errorMessage = chatProvider.errorMessage;

    // Scroll to bottom when new messages are added from provider
    // or when keyboard visibility changes.
    // This ensures the latest message is always visible.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    if (errorMessage != null && !isLoadingFromChatProvider && !_isErrorSnackbarShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.redAccent,
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () {
                  chatProvider.clearError();
                  _isErrorSnackbarShown = false;
                },
              ),
            ),
          );
          _isErrorSnackbarShown = true;
        }
      });
    } else if (errorMessage == null && _isErrorSnackbarShown) {
      _isErrorSnackbarShown = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orion'),
        actions: [
          if (authProvider.isLoading) // Global auth loading (e.g. sign-out)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            // The ListView.builder displays items from the 'messages' list.
            // With 'reverse: true', messages[0] is at the bottom, messages[length-1] is at the top.
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              reverse: true, // Crucial for chat UI: items build from bottom up
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                // 'messages' list is assumed to be ordered: newest first (index 0)
                // due to ChatProvider inserting new messages at index 0.
                final message = messages[index];
                return ChatMessageBubble(
                  message: message,
                );
              },
            ),
          ),
          // "Assistant is typing..." indicator
          if (isLoadingFromChatProvider && messages.isNotEmpty && messages.first.sender == MessageSender.assistant && messages.first.status == MessageStatus.sending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // Added more vertical padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  const SizedBox(width: 10),
                  Text(
                    "Assistant is thinking...",
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700, fontSize: 14),
                  ),
                ],
              ),
            ),
          MessageInputBar(
            controller: _textController,
            onSendPressed: _handleSendPressed,
            isSending: isLoadingFromChatProvider,
            onMicPressed: (inputMode == InputMode.text) ? null : _handleMicPressed,
            inputMode: inputMode,
            voiceButtonPosition: buttonPosition,
          ),
        ],
      ),
    );
  }
}
