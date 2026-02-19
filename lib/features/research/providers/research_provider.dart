import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/llm_model.dart';
import '../../../core/database.dart';
import '../models/research_models.dart';
import '../../models/models_provider.dart'; // Import models_provider for ollamaClientProvider
import '../services/research_repository.dart';
import '../services/document_processor.dart';
import '../../../services/ollama_client.dart';
import '../../../core/settings_service.dart';

// Services
final researchRepositoryProvider = Provider((ref) => ResearchRepository(DatabaseService()));
final documentProcessorProvider = Provider((ref) => DocumentProcessor());

class ResearchNotifier extends StateNotifier<ResearchState> {
  final ResearchRepository _repo;
  final DocumentProcessor _processor;
  final Ref _ref;

  ResearchNotifier(this._repo, this._processor, this._ref) : super(ResearchState()) {
    loadWorkspaces();
  }

  Future<void> loadWorkspaces() async {
    try {
      final workspaces = await _repo.getWorkspaces();
      state = state.copyWith(workspaces: workspaces);
    } catch (e) {
      state = state.copyWith(error: "Failed to load workspaces: $e");
    }
  }

  Future<void> createWorkspace(String name) async {
    final workspace = Workspace(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    await _repo.createWorkspace(workspace);
    await loadWorkspaces();
    selectWorkspace(workspace);
  }

  Future<void> selectWorkspace(Workspace workspace) async {
    state = state.copyWith(
      activeWorkspace: workspace, 
      messages: [], // Clear chat when switching
      documents: [],
    );
    await _loadDocuments(workspace.id);
  }

  Future<void> deleteWorkspace(String id) async {
    await _repo.deleteWorkspace(id);
    if (state.activeWorkspace?.id == id) {
      state = state.copyWith(activeWorkspace: null, documents: [], messages: []);
    }
    await loadWorkspaces();
  }

  Future<void> _loadDocuments(String workspaceId) async {
    final docs = await _repo.getDocuments(workspaceId);
    state = state.copyWith(documents: docs);
  }

  Future<void> importFile(String path) async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;

    final file = File(path);
    if (!file.existsSync()) return;

    final docId = const Uuid().v4();
    // Use last segment as filename
    final fileName = file.uri.pathSegments.last;
    
    final doc = ResearchDocument(
      id: docId,
      workspaceId: workspace.id,
      name: fileName,
      uploadedAt: DateTime.now(),
      processingStatus: 'processing',
    );

    // Optimistic update
    state = state.copyWith(documents: [doc, ...state.documents]);
    await _repo.createDocument(doc);
    
    // Process in background
    _processFile(file, workspace.id, docId);
  }

  Future<void> importFolder(String path) async {
      final workspace = state.activeWorkspace;
      if (workspace == null) return;
      
      final dir = Directory(path);
      if (!dir.existsSync()) return;
      
      // List all files recursively
      try {
        final List<FileSystemEntity> entities = await dir.list(recursive: true).toList();
        final files = entities.whereType<File>().toList();
        
        // Filter for interesting files to avoid junk (node_modules etc if huge)
        // For now, accept mostly text/code/pdf/images
        final allowedExt = ['.txt', '.md', '.dart', '.js', '.ts', '.py', '.json', '.yaml', '.xml', '.html', '.css', '.pdf', '.zip', '.jpg', '.png'];
        
        for (var file in files) {
           final ext = file.uri.pathSegments.last.split('.').last.toLowerCase();
           // Basic check if it has an extension method
           if (file.path.contains('.')) {
              final dotExt = ".${file.path.split('.').last.toLowerCase()}";
              if (allowedExt.contains(dotExt)) {
                  await importFile(file.path);
              }
           }
        }
      } catch (e) {
          state = state.copyWith(error: "Error importing folder: $e");
      }
  }

  Future<void> importLink(String url) async {
    final workspace = state.activeWorkspace;
    if (workspace == null) return;
    
    final docId = const Uuid().v4();
    final doc = ResearchDocument(
      id: docId,
      workspaceId: workspace.id,
      name: url, // Use URL as name
      uploadedAt: DateTime.now(),
      processingStatus: 'processing',
    );
    
    state = state.copyWith(documents: [doc, ...state.documents]);
    await _repo.createDocument(doc);
    
    _processUrl(url, workspace.id, docId);
  }

  Future<void> _processUrl(String url, String workspaceId, String docId) async {
       try {
          final chunks = await _processor.processUrl(url, workspaceId, docId);
          await _repo.insertChunks(chunks);
          await _loadDocuments(workspaceId);
       } catch (e) {
          state = state.copyWith(error: "Failed to process URL: $url");
       }
  }

  Future<void> _processFile(File file, String workspaceId, String docId) async {
    try {
      final chunks = await _processor.processFile(file, workspaceId, docId);
      await _repo.insertChunks(chunks);
      // Reload to get updated counts/status
      await _loadDocuments(workspaceId);
    } catch (e) {
      state = state.copyWith(error: "Failed to process ${file.path}");
    }
  }

  Future<void> deleteDocument(String id) async {
    await _repo.deleteDocument(id);
    if (state.activeWorkspace != null) {
      await _loadDocuments(state.activeWorkspace!.id);
    }
  }

  Future<void> query(String text) async {
    final workspace = state.activeWorkspace;
    if (workspace == null || text.trim().isEmpty) return;

    // Add User Message
    final userMsg = ResearchMessage(role: 'user', content: text);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isGenerating: true,
      error: null,
    );

    try {
      // 1. Retrieve
      final searchResults = await _repo.searchChunks(workspace.id, text);
      final chunks = searchResults.map((r) => r.chunk).toList();

      // 2. Compose Prompt
      String contextText;
      if (chunks.isEmpty) {
        contextText = "No specific documents found. Answer from general knowledge if possible, but clarify that no source was found.";
      } else {
        contextText = chunks.asMap().entries.map((e) {
          final idx = e.key + 1;
          final chunk = e.value;
          return "Source [$idx]:\n${chunk.content}\n";
        }).join("\n");
      }

      final fullPrompt = """
You are a research assistant. Use the following sources to answer the user's question.
If the answer is explicitly found in the sources, cite them like [1].
If the answer is not in the sources, state that clearly.

$contextText

Question: $text

Answer:
""";

      // 3. Generate
      final client = _ref.read(ollamaClientProvider);
      // Try getting active model, default to whatever is handy
      final activeModelName = _ref.read(activeModelNameProvider).valueOrNull ?? 'llama3';


      String accumulatedResponse = "";
      
      // Initial empty AI message to display loading/streaming state
      final aiMsgId = const Uuid().v4();
      var currentAiMsg = ResearchMessage(
        id: aiMsgId,
        role: 'ai', 
        content: "",
        citations: chunks
      );
      
      state = state.copyWith(
        messages: [...state.messages, currentAiMsg],
      );

      await for (final chunk in client.generateCompletion(activeModelName, fullPrompt)) {
        accumulatedResponse += chunk;
        
        // Update the last message with new content
        currentAiMsg = currentAiMsg.copyWith(content: accumulatedResponse);
        
        state = state.copyWith(
          messages: [
            ...state.messages.sublist(0, state.messages.length - 1),
            currentAiMsg
          ]
        );
      }
      
      state = state.copyWith(isGenerating: false);

    } catch (e) {
      state = state.copyWith(
        isGenerating: false, 
        error: "Query failed: $e",
        messages: [...state.messages, ResearchMessage(role: 'ai', content: "Error: $e")]
      );
    }
  }
}

final researchProvider = StateNotifierProvider<ResearchNotifier, ResearchState>((ref) {
  final repo = ref.watch(researchRepositoryProvider);
  final processor = ref.watch(documentProcessorProvider);
  return ResearchNotifier(repo, processor, ref);
});

