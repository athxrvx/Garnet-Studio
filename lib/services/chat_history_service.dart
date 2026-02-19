import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/chat_session.dart';

final chatHistoryServiceProvider = Provider<ChatHistoryService>((ref) => ChatHistoryService());

class ChatHistoryService {
  Future<String> _getDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/GarnetStudio/chats';
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<List<ChatSession>> loadAllSessions() async {
    try {
      final path = await _getDirectoryPath();
      final dir = Directory(path);
      if (!await dir.exists()) return [];

      final List<ChatSession> sessions = [];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final json = jsonDecode(content);
            sessions.add(ChatSession.fromJson(json));
          } catch (e) {
            print('Error loading session ${entity.path}: $e');
          }
        }
      }
      // Sort by date desc
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return sessions;
    } catch (e) {
      print('Error loading sessions: $e');
      return [];
    }
  }

  Future<void> saveSession(ChatSession session) async {
    try {
      final path = await _getDirectoryPath();
      final file = File('$path/${session.id}.json');
      await file.writeAsString(jsonEncode(session.toJson()));
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final path = await _getDirectoryPath();
      final file = File('$path/$sessionId.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting session: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      final path = await _getDirectoryPath();
      final dir = Directory(path);
      if (await dir.exists()) {
        // Delete all JSON files in the directory
        await for (final entity in dir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error clearing history: $e');
    }
  }
}
