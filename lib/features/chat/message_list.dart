import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_bubble.dart';
import 'chat_provider.dart';

class MessageList extends ConsumerWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);

    if (messages.isEmpty) {
       return Center(
         child: Text("Start a conversation", style: TextStyle(color: Colors.white24)),
       );
    }
    
    // Auto scroll to bottom
    // For simplicity, we just rebuild list. In prod, use ScrollController
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return ChatBubble(message: message);
      },
    );
  }
}
