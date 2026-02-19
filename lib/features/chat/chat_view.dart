import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/chat_message.dart';
import 'chat_provider.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isWebSearch = ref.watch(isWebSearchEnabledProvider);
    final isDeepResearch = ref.watch(isDeepResearchEnabledProvider);
    final isKnowledgeBase = ref.watch(isResearchContextEnabledProvider); 

    // Scroll to bottom when messages change
    ref.listen(chatMessagesProvider, (previous, next) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });

    return Column(
      children: [
        // Mode Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: Theme.of(context).colorScheme.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text("Tools: ", style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text("Web"),
                  selected: isWebSearch,
                  onSelected: (val) {
                    ref.read(isWebSearchEnabledProvider.notifier).state = val;
                    if (val) ref.read(isDeepResearchEnabledProvider.notifier).state = false;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text("Knowledge Base"),
                  selected: isKnowledgeBase,
                  onSelected: (val) {
                    ref.read(isResearchContextEnabledProvider.notifier).state = val;
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text("Deep Research"),
                  selected: isDeepResearch,
                  onSelected: (val) {
                    ref.read(isDeepResearchEnabledProvider.notifier).state = val;
                    if (val) ref.read(isWebSearchEnabledProvider.notifier).state = false;
                  },
                ),
              ],
            ),
          ),
        ),
        
        // Message List
        Expanded(
          child: messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text("Garnet Studio Chat", style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      "Ask about anything or search your documents", 
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
        ),

        // Input Area
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      ref.read(chatMessagesProvider.notifier).sendUserMessage(text);
      _textController.clear();
    }
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.role == MessageRole.user;
    final isSystem = msg.role == MessageRole.system;
    
    if (isSystem) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.symmetric(vertical: 8.0),
           child: Text(msg.content, style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic)),
         ),
       );
    }

    final bubble = Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 650),
        decoration: BoxDecoration(
          color: isUser 
              ? Theme.of(context).colorScheme.primaryContainer 
              : const Color(0xFF2A2A2A), 
          borderRadius: BorderRadius.only(
            topLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            topRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: msg.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 14),
                code: TextStyle(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  fontFamily: 'Consolas',
                ),
              ),
            ),
            if (msg.isStreaming)
               const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))),
          ],
        ),
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
           Padding(
             padding: const EdgeInsets.only(right: 12, top: 12),
             child: CircleAvatar(
               radius: 16,
               backgroundColor: Colors.transparent,
               backgroundImage: const AssetImage('assets/logo.png'),
             ),
           ),
           Flexible(child: bubble),
        ],
      ),
    );
  }
}

