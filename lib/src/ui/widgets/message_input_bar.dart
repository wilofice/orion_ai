import 'package:flutter/material.dart';
import '../../preferences/user_preferences.dart';

class MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSendPressed;
  final VoidCallback? onMicPressed; // Optional microphone button
  final bool isSending; // To disable while a message is being processed
  final InputMode inputMode;
  final VoiceButtonPosition voiceButtonPosition;

  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onSendPressed,
    this.onMicPressed,
    this.isSending = false,
    this.inputMode = InputMode.text,
    this.voiceButtonPosition = VoiceButtonPosition.right,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void addMicButton() {
      if (onMicPressed != null) {
        children.add(
          IconButton(
            icon: Icon(Icons.mic_none_outlined,
                color: Theme.of(context).colorScheme.primary),
            onPressed: isSending ? null : onMicPressed,
          ),
        );
      }
    }

    void addTextField() {
      children.add(
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Type a message...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            ),
            enabled: !isSending,
            onSubmitted: (_) => onSendPressed(),
          ),
        ),
      );
    }

    if (inputMode == InputMode.voice) {
      addMicButton();
    } else if (inputMode == InputMode.text) {
      addTextField();
      children.add(const SizedBox(width: 8.0));
      children.add(
        IconButton(
          icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
          onPressed: isSending ? null : onSendPressed,
        ),
      );
    } else {
      if (voiceButtonPosition == VoiceButtonPosition.left) {
        addMicButton();
      }
      addTextField();
      if (voiceButtonPosition == VoiceButtonPosition.right) {
        addMicButton();
      }
      children.add(const SizedBox(width: 8.0));
      children.add(
        IconButton(
          icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
          onPressed: isSending ? null : onSendPressed,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(children: children),
    );
  }
}