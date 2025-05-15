// lib/src/chat/chat_screen.dart

import 'package:flutter/material.dart';
import '/src/ui/widgets/chat_message_bubble.dart'; // Adjust path
import '/src/ui/widgets/message_input_bar.dart'; // Adjust path
import '/src/chat/chat_provider.dart'; // Adjust path
import '/src/auth/auth_provider.dart'; // Adjust path for user ID
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
  // Local state to track if an error SnackBar is currently shown
  // to prevent showing multiple snackbars for the same error.
  bool _isErrorSnackbarShown = false;


  @override
  void initState() {
    super.initState();
    // Listen to messages to scroll down
    // Using WidgetsBinding to ensure provider is available after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Access provider once here if needed for initial setup
      // final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      // Example: if you need to load initial messages or something
      // chatProvider.loadInitialMessages(); // Hypothetical method
      _scrollToBottom(); // Initial scroll if there are messages (e.g., welcome message)
    });
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      // Delay slightly to allow list to render before scrolling
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0, // For reversed list, 0.0 is the bottom (most recent)
            duration: Duration(milliseconds: animate ? 300 : 0),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleSendPressed() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      return;
    }

    // Get providers without listening for this specific action
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    if (authProvider.currentUser == null) {
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
    // The userId is passed to the provider method
    chatProvider.sendUserMessage(text, authProvider.currentUser!.uid);

    _textController.clear();
    FocusScope.of(context).unfocus(); // Dismiss keyboard
    // _scrollToBottom(); // Scroll will be triggered by message list update
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use context.watch to listen for changes in ChatProvider and AuthProvider
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>(); // For auth status if needed

    final messages = chatProvider.messages;
    final isLoadingFromChatProvider = chatProvider.isLoading; // For assistant typing
    final errorMessage = chatProvider.errorMessage;

    // Scroll to bottom when new messages are added from provider
    // or when keyboard visibility changes (though KeyboardAvoidingView helps)
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Display error messages using SnackBar if an error occurs
    if (errorMessage != null && !isLoadingFromChatProvider && !_isErrorSnackbarShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Ensure widget is still in the tree
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.redAccent,
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () {
                  chatProvider.clearError(); // Clear error on dismiss
                  _isErrorSnackbarShown = false;
                },
              ),
            ),
          );
          _isErrorSnackbarShown = true; // Set flag to prevent multiple snackbars
        }
      });
    } else if (errorMessage == null && _isErrorSnackbarShown) {
      // Reset flag if error is cleared
      _isErrorSnackbarShown = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orion Chat'),
        // Example: Show global loading from AuthProvider (e.g. during sign-out)
        actions: [
          if (authProvider.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              reverse: true, // Crucial for chat UI
              itemCount: messages.length,
              itemBuilder: (BuildContext context, int index) {
                final message = messages[index];
                return ChatMessageBubble(
                  message: message,
                  // TODO: Implement retry for error bubbles.
                  // This would typically involve storing the failed message details
                  // and calling a retry method in ChatProvider.
                  // onTap: message.status == MessageStatus.error
                  //     ? () {
                  //         print("Retry message ID: ${message.id}");
                  //         // chatProvider.retrySendMessage(message.id); // Example
                  //       }
                  //     : null,
                );
              },
            ),
          ),
          // Display "Assistant is typing..." indicator
          if (isLoadingFromChatProvider && messages.isNotEmpty && messages.first.sender == MessageSender.assistant && messages.first.status == MessageStatus.sending)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(
                    "Assistant is thinking...",
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          MessageInputBar(
            controller: _textController,
            onSendPressed: _handleSendPressed,
            isSending: isLoadingFromChatProvider, // Disable input bar while assistant is "typing"
            // onMicPressed: () { print("Mic pressed - To be implemented"); },
          ),
        ],
      ),
    );
  }
}
