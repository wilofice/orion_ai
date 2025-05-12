import 'package:flutter/material.dart';
import '../ui/widgets/chat_message_bubble.dart'; // Adjust path
import '../ui/widgets/message_input_bar.dart'; // Adjust path
import 'package:provider/provider.dart'; // For later integration with ChatManager/AuthProvider
import '/src/auth/auth_provider.dart'; // For user ID

// Using the ChatMessage model from chat_message_bubble.dart for now
// In a larger app, this would be in a shared models directory.

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = []; // Start with empty or welcome message
  final ScrollController _scrollController = ScrollController(); // For scrolling to bottom

  @override
  void initState() {
    super.initState();
    // Add initial welcome message
    _messages.insert(0, ChatMessage(
        id: 'assistant-welcome',
        text: 'Hello! How can I assist with your schedule today?',
        sender: MessageSender.assistant,
        timestamp: DateTime.now()
    ));
  }

  // Placeholder for send logic (will be expanded in FE-TASK-10)
  void _handleSendPressed() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final userMessage = ChatMessage(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}', // Simple unique ID
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.insert(0, userMessage); // Add to beginning for reversed list
    });
    _textController.clear();

    // Simulate assistant response for UI testing
    Future.delayed(const Duration(milliseconds: 500), () {
      final assistantLoadingMessage = ChatMessage(
          id: 'assistant-loading-${DateTime.now().millisecondsSinceEpoch}',
          text: '',
          sender: MessageSender.assistant,
          timestamp: DateTime.now(),
          status: MessageStatus.sending
      );
      setState(() {
        _messages.insert(0, assistantLoadingMessage);
      });

      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          // Find and replace the loading message
          final loadingIndex = _messages.indexWhere((msg) => msg.id == assistantLoadingMessage.id);
          if (loadingIndex != -1) {
            _messages[loadingIndex] = ChatMessage(
                id: assistantLoadingMessage.id, // Keep same ID to update
                text: 'Sure, I can help with "$text". What are the details?',
                sender: MessageSender.assistant,
                timestamp: DateTime.now(),
                status: MessageStatus.sent
            );
          }
        });
      });
    });

    // Scroll to bottom after adding message
    // With reversed list, scroll to offset 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orion Chat'),
        // Add other actions if needed, e.g., clear chat
      ),
      // Step 7.5: resizeToAvoidBottomInset is true by default for Scaffold
      // which handles keyboard adjustment.
      body: Column(
        children: <Widget>[
          Expanded(
            // Step 7.4: ListView.builder for messages
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              reverse: true, // Crucial for chat UI
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final message = _messages[index];
                return ChatMessageBubble(message: message);
              },
            ),
          ),
          // Step 7.3 & 7.6: MessageInputBar
          MessageInputBar(
            controller: _textController,
            onSendPressed: _handleSendPressed,
            // onMicPressed: () { print("Mic pressed"); }, // Placeholder for voice
          ),
        ],
      ),
    );
  }
}