import 'package:flutter/material.dart';

class MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSendPressed;
  final VoidCallback? onMicPressed; // Optional microphone button
  final bool isSending; // To disable while a message is being processed

  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onSendPressed,
    this.onMicPressed,
    this.isSending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Or specific background color
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: <Widget>[
          // Optional: Microphone button
          if (onMicPressed != null)
            IconButton(
              icon: Icon(Icons.mic_none_outlined, color: Theme.of(context).colorScheme.primary),
              onPressed: isSending ? null : onMicPressed,
            ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5, // Allow multiline input
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor, // Or a slightly different shade
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              ),
              enabled: !isSending,
              onSubmitted: (_) => onSendPressed(), // Allow sending with keyboard action,
            ),
          ),
          const SizedBox(width: 8.0),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
            onPressed: (isSending) ? null : onSendPressed,
          ),
        ],
      ),
    );
  }
}