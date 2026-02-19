import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/constants/app_constants.dart';
import '../../models/chat_message.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppConstants.lighterBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          border: isUser ? null : Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser) // Only show header for assistant
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, size: 14, color: AppConstants.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      'Assistant',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            MarkdownBody(
              data: message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 15, height: 1.5, color: Colors.white),
                code: const TextStyle(
                  backgroundColor: Colors.transparent,
                  color: Colors.orange, // Replaces Amber[100]
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
