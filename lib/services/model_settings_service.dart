import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database.dart';
import '../core/models/llm_model.dart';

class ModelSettingsService {
  final DatabaseService _dbService;

  ModelSettingsService(this._dbService);

  // Syncs the list of models from Ollama with the SQLite database
  Future<void> syncModels(List<Map<String, dynamic>> ollamaModels) async {
    final db = await _dbService.database;
    
    // Get existing models from DB
    final existingModels = await db.query('models');
    final existingNames = existingModels.map((m) => m['name'] as String).toSet();
    final newNames = ollamaModels.map((m) => m['name'] as String).toSet();

    // 1. Insert new models (if not exists)
    for (var model in ollamaModels) {
      if (!existingNames.contains(model['name'])) {
        await db.insert('models', {
          'name': model['name'],
          'size': model['size'] ?? 0,
          'installed_at': model['modified_at'] ?? DateTime.now().toIso8601String(),
          'is_active': 0, // Default to inactive
          // Use table defaults for other fields
        });
      } else {
         // Update size/modified date if changed
         await db.update('models', {
           'size': model['size'],
           'installed_at': model['modified_at']
         }, where: 'name = ?', whereArgs: [model['name']]);
      }
    }

    // 2. Remove models that are no longer installed
    for (var name in existingNames) {
      if (!newNames.contains(name)) {
        await db.delete('models', where: 'name = ?', whereArgs: [name]);
      }
    }
  }

  Future<List<LocalModel>> getAllModels() async {
    final db = await _dbService.database;
    final results = await db.query('models');
    
    return results.map((row) {
      // Need to cast types carefully as Sqflite returns Object?
      return LocalModel(
        name: row['name'] as String,
        size: row['size'] as int,
        modifiedAt: DateTime.tryParse(row['installed_at'] as String? ?? '') ?? DateTime.now(),
        digest: 'unknown', // not storing digest currently, usually irrelevant for UI
        isActive: (row['is_active'] as int) == 1,
        temperature: row['temperature'] as double,
        topP: row['top_p'] as double,
        topK: row['top_k'] as int,
        contextLength: row['context_length'] as int,
        systemPrompt: row['system_prompt'] as String? ?? '',
        maxTokens: row['max_tokens'] as int,
      );
    }).toList();
  }

  Future<void> setActiveModel(String name) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      // Unset all
      await txn.update('models', {'is_active': 0});
      // Set target
      await txn.update('models', {'is_active': 1}, where: 'name = ?', whereArgs: [name]);
      // Update global settings table for legacy/other components
      await txn.insert('settings', {'key': 'active_model', 'value': name}, 
        conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> clearActiveModel() async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      // Unset all
      await txn.update('models', {'is_active': 0});
      // Clear global setting
      await txn.delete('settings', where: 'key = ?', whereArgs: ['active_model']);
    });
  }

  Future<void> updateModelConfig(String name, {
    double? temperature,
    double? topP,
    int? topK,
    int? contextLength,
    String? systemPrompt,
    int? maxTokens,
  }) async {
    final db = await _dbService.database;
    final updates = <String, dynamic>{};
    if (temperature != null) updates['temperature'] = temperature;
    if (topP != null) updates['top_p'] = topP;
    if (topK != null) updates['top_k'] = topK;
    if (contextLength != null) updates['context_length'] = contextLength;
    if (systemPrompt != null) updates['system_prompt'] = systemPrompt;
    if (maxTokens != null) updates['max_tokens'] = maxTokens;

    if (updates.isNotEmpty) {
      await db.update('models', updates, where: 'name = ?', whereArgs: [name]);
    }
  }
}
