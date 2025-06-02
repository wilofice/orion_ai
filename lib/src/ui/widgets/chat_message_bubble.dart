import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting (add intl to pubspec.yaml)
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

// Define a model for chat messages (can be moved to a dedicated models file later)
enum MessageSender { user, assistant }
enum MessageStatus { sending, sent, error }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final String? audioUrl;
  final MessageStatus? status; // For UI feedback on user messages or assistant loading

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.audioUrl,
    this.status,
  });
}

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.sender == MessageSender.user;
    final CrossAxisAlignment bubbleAlignment =
    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final Color bubbleColor =
    isUser ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondaryContainer;
    final Color textColor = isUser
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSecondaryContainer;
    final Radius userRadius = Radius.circular(isUser ? 5 : 16);
    final Radius assistantRadius = Radius.circular(isUser ? 16 : 5);


    Widget messageContent;
    if (message.status == MessageStatus.sending && message.sender == MessageSender.assistant) {
      messageContent = SizedBox(
        width: 50, // Give some width to the typing indicator
        height: 20, // Give some height
        child: Center(
          child: SizedBox(
            width: 15, height: 15, // Smaller spinner
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
        ),
      );
    } else {
      final parts = <Widget>[];
      if (message.audioUrl != null) {
        parts.add(Row(
          children: [
            const Icon(Icons.play_arrow, size: 16),
            const SizedBox(width: 4),
            Text('Audio', style: TextStyle(color: textColor)),
          ],
        ));
        parts.add(const SizedBox(height: 4));
      }
      parts.add(Linkify(
        text: message.text,
        onOpen: (link) async {
          final uri = Uri.parse(link.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        style: TextStyle(color: textColor, fontSize: 16),
        linkStyle: const TextStyle(
          color: Colors.blueAccent,
          decoration: TextDecoration.underline,
        ),
      ));
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: bubbleAlignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75, // Max width 75%
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: assistantRadius, // Different for user/assistant
                bottomRight: userRadius,    // Different for user/assistant
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Text inside bubble aligns left
              children: [
                messageContent,
                if (message.status == MessageStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '⚠️ Failed. Tap to retry?', // Example error text
                      style: TextStyle(color: Colors.red.shade300, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2.0, left: 8.0, right: 8.0),
            child: Text(
              DateFormat('HH:mm').format(message.timestamp), // Example: 14:30
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          )
        ],
      ),
    );
  }
}