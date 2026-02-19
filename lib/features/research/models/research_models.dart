
import 'package:uuid/uuid.dart';

class Workspace {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt; // Added

  Workspace({
    required this.id, 
    required this.name, 
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  // Add copyWith and fromMap logic if needed, but keeping simple for now
}

class ResearchDocument {
  final String id;
  final String workspaceId;
  final String name; // Reverted to name
  final DateTime uploadedAt;
  final int chunkCount;
  final String processingStatus; 

  ResearchDocument({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.uploadedAt,
    this.chunkCount = 0,
    this.processingStatus = 'pending',
  });
}

class DocumentChunk {
  final String id;
  final String documentId;
  final String workspaceId;
  final String content;
  final String? embedding; 
  final int chunkIndex;

  DocumentChunk({
    required this.id,
    required this.documentId,
    required this.workspaceId,
    required this.content,
    this.embedding,
    required this.chunkIndex,
  });
}

class SearchResult {
  final DocumentChunk chunk;
  final double score;

  SearchResult(this.chunk, this.score);
}

class ResearchMessage {
  final String id; // Added id for better keying
  final String role; // 'user', 'ai'
  final String content;
  final List<DocumentChunk>? citations;

  ResearchMessage({
    String? id,
    required this.role, 
    required this.content, 
    this.citations
  }) : id = id ?? const Uuid().v4();

  ResearchMessage copyWith({
    String? id,
    String? role,
    String? content,
    List<DocumentChunk>? citations,
  }) {
    return ResearchMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      citations: citations ?? this.citations,
    );
  }
}

class ResearchState {
  final List<Workspace> workspaces;
  final Workspace? activeWorkspace;
  final List<ResearchDocument> documents;
  final List<ResearchMessage> messages;
  final bool isGenerating;
  final String? error;

  ResearchState({
    this.workspaces = const [],
    this.activeWorkspace,
    this.documents = const [],
    this.messages = const [],
    this.isGenerating = false,
    this.error,
  });

  ResearchState copyWith({
    List<Workspace>? workspaces,
    Workspace? activeWorkspace,
    List<ResearchDocument>? documents,
    List<ResearchMessage>? messages,
    bool? isGenerating,
    String? error,
  }) {
    return ResearchState(
      workspaces: workspaces ?? this.workspaces,
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      documents: documents ?? this.documents,
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

