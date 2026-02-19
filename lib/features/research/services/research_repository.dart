import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../../core/database.dart';
import '../models/research_models.dart';

class ResearchRepository {
  final DatabaseService _dbService;

  ResearchRepository(this._dbService);

  // --- Workspaces ---

  Future<List<Workspace>> getWorkspaces() async {
    final db = await _dbService.database;
    final results = await db.query('workspaces', orderBy: 'created_at DESC');
    return results.map((row) => Workspace(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    )).toList();
  }

  Future<void> createWorkspace(Workspace workspace) async {
    final db = await _dbService.database;
    await db.insert('workspaces', {
      'id': workspace.id,
      'name': workspace.name,
      'created_at': workspace.createdAt.toIso8601String(),
    });
  }

  Future<void> deleteWorkspace(String id) async {
    final db = await _dbService.database;
    await db.delete('workspaces', where: 'id = ?', whereArgs: [id]);
  }

  // --- Documents ---

  Future<List<ResearchDocument>> getDocuments(String workspaceId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'documents',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'uploaded_at DESC',
    );
    return results.map((row) => ResearchDocument(
      id: row['id'] as String,
      workspaceId: row['workspace_id'] as String,
      name: row['name'] as String,
      uploadedAt: DateTime.parse(row['uploaded_at'] as String),
      chunkCount: row['chunk_count'] as int,
      processingStatus: row['processing_status'] as String,
    )).toList();
  }

  Future<void> createDocument(ResearchDocument doc) async {
    final db = await _dbService.database;
    await db.insert('documents', {
      'id': doc.id,
      'workspace_id': doc.workspaceId,
      'name': doc.name,
      'uploaded_at': doc.uploadedAt.toIso8601String(),
      'chunk_count': doc.chunkCount,
      'processing_status': doc.processingStatus,
    });
  }

  Future<void> deleteDocument(String id) async {
    final db = await _dbService.database;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  // --- Chunks ---

  Future<void> insertChunks(List<DocumentChunk> chunks) async {
    final db = await _dbService.database;
    final batch = db.batch();
    for (var chunk in chunks) {
      batch.insert('chunks', {
        'id': chunk.id,
        'document_id': chunk.documentId,
        'workspace_id': chunk.workspaceId,
        'content': chunk.content,
        'embedding': chunk.embedding,
        'chunk_index': chunk.chunkIndex,
      });
    }
    await batch.commit(noResult: true);
    
    // Update document chunk count and status
    if (chunks.isNotEmpty) {
      await db.update(
        'documents', 
        {'chunk_count': chunks.length, 'processing_status': 'processed'},
        where: 'id = ?',
        whereArgs: [chunks.first.documentId]
      );
    }
  }

  Future<List<SearchResult>> searchChunks(String workspaceId, String query) async {
    final db = await _dbService.database;
    
    // Strategy 1: exact phrase match
    var results = await db.query(
      'chunks',
      where: 'workspace_id = ? AND content LIKE ?',
      whereArgs: [workspaceId, '%$query%'],
      limit: 5,
    );
    
    // Strategy 2: If no exact match, try matching individual terms (simplistic OR)
    if (results.isEmpty) {
        final terms = query.split(' ').where((s) => s.length > 3).toList();
        if (terms.isNotEmpty) {
           final whereClause = terms.map((_) => 'content LIKE ?').join(' OR ');
           final args = terms.map((t) => '%$t%').toList();
           
           results = await db.query(
              'chunks',
              where: 'workspace_id = ? AND ($whereClause)',
              whereArgs: [workspaceId, ...args],
              limit: 5,
           );
        }
    }
    
       // 3. Generate
    // Strategy 3: Just return everything if workspace is small (Context Stuffing for small docs)
    // This is crucial for "Chat with PDF" where the user asks "summarize this" without keywords.
    if (results.isEmpty) {
       final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM chunks WHERE workspace_id = ?', [workspaceId]);
       // Sqflite.firstIntValue replacment to avoid import issues
       int count = 0;
       if (countResult.isNotEmpty && countResult.first.isNotEmpty) {
          final value = countResult.first.values.first;
          if (value is int) {
            count = value;
          }
       }
       
       if (count < 50) { // If less than ~50 chunks (approx 10-20k tokens depending on chunk size), just return all.
          results = await db.query(
             'chunks',
             where: 'workspace_id = ?',
             whereArgs: [workspaceId],
             limit: 50,
          );
       }
    }

    return results.map((row) {
      final chunk = DocumentChunk(
        id: row['id'] as String,
        documentId: row['document_id'] as String,
        workspaceId: row['workspace_id'] as String,
        content: row['content'] as String,
        embedding: row['embedding'] as String?,
        chunkIndex: row['chunk_index'] as int,
      );
      // Fake score for LIKE match
      return SearchResult(chunk, 1.0); 
    }).toList();
  }

  Future<List<SearchResult>> searchGlobalChunks(String query) async {
    final db = await _dbService.database;
    
    // 1. Try Simple Keyword Search (OR-based)
    // Extract meaningful terms (length > 3) to avoid "what", "is", "the"
    final terms = query.split(RegExp(r'\s+')).where((s) => s.length > 3).toList();
    List<Map<String, Object?>> results = [];

    if (terms.isNotEmpty) {
        final whereClause = terms.map((_) => 'content LIKE ?').join(' OR ');
        final args = terms.map((t) => '%$t%').toList();
        
        results = await db.query(
          'chunks',
          where: whereClause,
          whereArgs: args,
          limit: 15,
        );
    }
    
    // 2. Fallback: If no keywords worked (e.g. "Summarize everything"), context stuff recent chunks
    if (results.isEmpty) {
       // Just grab the latest chunks uploaded to the system
       results = await db.query(
          'chunks',
          orderBy: 'rowid DESC', // In SQLite, rowid roughly correlates to insertion order
          limit: 20,
       );
    }

    return results.map((row) {
      final chunk = DocumentChunk(
        id: row['id'] as String,
        documentId: row['document_id'] as String,
        workspaceId: row['workspace_id'] as String,
        content: row['content'] as String,
        embedding: row['embedding'] as String?,
        chunkIndex: row['chunk_index'] as int,
      );
      return SearchResult(chunk, 1.0); 
    }).toList();
  }
}

