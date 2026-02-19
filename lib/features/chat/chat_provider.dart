import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_message.dart';
import '../../models/chat_session.dart';
import '../../services/ollama_service.dart';
import '../../services/web_search_service.dart';
import '../../services/chat_history_service.dart';
import '../../core/settings_service.dart'; // Added import
import 'ollama_provider.dart';
import '../research/providers/research_provider.dart'; // Import Research Provider

// Notifiers implementation to replace StateProvider (removed in Riverpod 3.0)

class BooleanNotifier extends Notifier<bool> {
  final bool initialValue;
  BooleanNotifier([this.initialValue = false]);
  
  @override
  bool build() => initialValue;
  
  // Expose state setter
  set state(bool value) => super.state = value;
  @override
  bool get state => super.state;
}

class StringNotifier extends Notifier<String> {
  final String initialValue;
  StringNotifier([this.initialValue = '']);

  @override
  String build() => initialValue;
  
   set state(String value) => super.state = value;
   @override
   String get state => super.state;
}

class NullableStringNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  
   set state(String? value) => super.state = value;
   @override
   String? get state => super.state;
}

// State Providers Replaced with NotifierProviders
final isWebSearchEnabledProvider = NotifierProvider<BooleanNotifier, bool>(() => BooleanNotifier(false));
final isDeepResearchEnabledProvider = NotifierProvider<BooleanNotifier, bool>(() => BooleanNotifier(false));
final isResearchContextEnabledProvider = NotifierProvider<BooleanNotifier, bool>(() => BooleanNotifier(true)); // Default ON for Knowledge Base integration
final currentViewProvider = NotifierProvider<StringNotifier, String>(() => StringNotifier('dashboard')); // dashboard or chat
final currentSessionIdProvider = NotifierProvider<NullableStringNotifier, String?>(() => NullableStringNotifier());

// History Loader
final chatSessionsProvider = FutureProvider<List<ChatSession>>((ref) async {
  // Watch this provider to reload list when this provider is invalidated
  final historyService = ref.watch(chatHistoryServiceProvider);
  return await historyService.loadAllSessions();
});

final chatMessagesProvider = NotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(() {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends Notifier<List<ChatMessage>> {
  final _ollamaService = OllamaService();
  final _webSearchService = WebSearchService();
  
  // Debounce saving
  ChatSession? _currentSession;

  @override
  List<ChatMessage> build() {
    return [];
  }

  Future<void> loadSession(ChatSession session) async {
     state = session.messages;
     _currentSession = session;
     ref.read(currentSessionIdProvider.notifier).state = session.id;
     ref.read(currentViewProvider.notifier).state = 'chat';
  }

  void startNewChat({String? initialMessage}) {
     state = [];
     _currentSession = null;
     ref.read(currentSessionIdProvider.notifier).state = null;
     ref.read(currentViewProvider.notifier).state = 'chat';
     
     if (initialMessage != null && initialMessage.isNotEmpty) {
       sendUserMessage(initialMessage);
     }
  }

  void addMessage(ChatMessage message) {
    state = [...state, message];
    _saveSession();
  }

  // Allow external sources (e.g. Server) to append content to a message
  void appendToMessage(String id, String chunk) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(content: m.content + chunk);
      }
      return m;
    }).toList();
  }
  
  // Allow external sources to set streaming status
  void setMessageStreaming(String id, bool isStreaming) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(isStreaming: isStreaming);
      }
      return m;
    }).toList();
    if (!isStreaming) _saveSession();
  }

  Future<void> sendUserMessage(String content) async {
    // 1. Check if we need to create a session
    if (_currentSession == null) {
      final newId = const Uuid().v4();
      _currentSession = ChatSession(
        id: newId,
        title: content.length > 30 ? '${content.substring(0, 30)}...' : content,
        updatedAt: DateTime.now(),
        messages: [],
      );
      ref.read(currentSessionIdProvider.notifier).state = newId;
    }

    // 2. Add User Message
    final userMsg = ChatMessage(
        id: const Uuid().v4(),
        content: content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
    );
    addMessage(userMsg);
    
    // 3. Prepare Context (Web Search / Deep Research / Knowledge Base)
    // Always inject current date/time context for better awareness
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    String? effectivePrompt; // Only set if search/research is active

    final isWebSearch = ref.read(isWebSearchEnabledProvider);
    final isDeepResearch = ref.read(isDeepResearchEnabledProvider);
    final isResearchContext = ref.read(isResearchContextEnabledProvider);

    if (isDeepResearch) {
       // ... existing deep research logic ...
       // Add a system update message
       final systemId = const Uuid().v4();
       addMessage(ChatMessage(id: systemId, content: "Performing Deep Research...", role: MessageRole.system, timestamp: DateTime.now()));
       
       final research = await _webSearchService.deepResearch(content);
       effectivePrompt = """
       Current Date: $dateStr
       
       Use the following research report to answer the user's request.
       
       --- RESEARCH REPORT ---
       $research
       --- END REPORT ---
       
       User Request: $content
       """;
    } else if (isWebSearch) {
       final systemId = const Uuid().v4();
       addMessage(ChatMessage(id: systemId, content: "Searching web...", role: MessageRole.system, timestamp: DateTime.now()));
    
       final results = await _webSearchService.search(content);
       final contextStr = results.isEmpty ? "No search results found." : results.join('\n\n');
       
       effectivePrompt = """
       Current Date: $dateStr
       
       Use the following search results to answer the user's request.
       
       --- SEARCH RESULTS ---
       $contextStr
       --- END RESULTS ---
       
       User Request: $content
       """;
    } else if (isResearchContext) {
       // Search Knowledge Base (Research Engine)
       try {
         final repo = ref.read(researchRepositoryProvider);
         final results = await repo.searchGlobalChunks(content);
         
         if (results.isNotEmpty) {
            final contextStr = results.map((r) => r.chunk.content).join('\n---\n');
            effectivePrompt = """
Use the following knowledge base context to answer the user's request.

--- KNOWLEDGE BASE CONTEXT ---
$contextStr
--- END CONTEXT ---

User Request: $content
""";
         }
       } catch (e) {
          // Fail silently or log
          print("Knowledge Base Search Failed: $e");
       }
    }

    // 4. Create Assistant Message Placeholder
    final assistantMsgId = const Uuid().v4();
    final assistantMsg = ChatMessage(
        id: assistantMsgId,
        content: '',
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
        isStreaming: true,
    );
    addMessage(assistantMsg);
    
    // Get currently selected model
    final selectedModel = ref.read(selectedModelProvider);

    try {
        // Filter out existing system messages from state (like "Searching web...")
        final history = state.where((m) => m.id != assistantMsgId && m.role != MessageRole.system).toList();
        
        // Inject System Prompt from Settings
        final settings = ref.read(settingsServiceProvider);
        final customPrompt = await settings.getSetting('system_prompt');
        final userName = await settings.getSetting('user_name');

        String finalSystemPrompt = customPrompt ?? "You are Garnet, a helpful and friendly AI assistant. Be concise.";
        
        // Append user identity if known
        if (userName != null && userName.isNotEmpty) {
           finalSystemPrompt += "\n\nThe user's name is $userName. Address them by name occasionally.";
        }
        
        // Append Date Context to System Prompt, not User Message
        finalSystemPrompt += "\nCurrent Date: $dateStr";

        final systemMessage = ChatMessage(
            id: 'system_branding',
            content: finalSystemPrompt,
            role: MessageRole.system,
            timestamp: DateTime.now(),
        );

        // Construct API payload
        final apiMessages = [systemMessage, ...history];
        
        // Replace the last user message content ONLY if effectivePrompt was modified by search/research
        if (effectivePrompt != null && apiMessages.isNotEmpty && apiMessages.last.role == MessageRole.user) {
             final last = apiMessages.removeLast();
             apiMessages.add(last.copyWith(content: effectivePrompt));
        }

        final stream = _ollamaService.generateChatStream(
            apiMessages, 
            selectedModel
        );
        
        await for (final chunk in stream) {
            state = state.map((m) {
                if (m.id == assistantMsgId) {
                    return m.copyWith(content: m.content + chunk);
                }
                return m;
            }).toList();
        }
    } catch (e) {
        state = state.map((m) {
            if (m.id == assistantMsgId) {
                return m.copyWith(content: "Error: $e");
            }
            return m;
        }).toList();
    } finally {
        state = state.map((m) {
            if (m.id == assistantMsgId) {
                return m.copyWith(isStreaming: false);
            }
            return m;
        }).toList();
        _saveSession();
    }
  }
  
  void _saveSession() {
     if (_currentSession != null) {
        final updatedSession = _currentSession!.copyWith(
          messages: state,
          updatedAt: DateTime.now(),
        );
        _currentSession = updatedSession;
        ref.read(chatHistoryServiceProvider).saveSession(updatedSession).then((_) {
           ref.invalidate(chatSessionsProvider); // Reload list in sidebar
        });
     }
  }
}
