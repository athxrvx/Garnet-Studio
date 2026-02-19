import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database.dart';

class SettingsService {
  final DatabaseService _db;

  SettingsService(this._db);

  Future<String?> getSetting(String key) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(DatabaseService());
});

final activeModelNameProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  return await settings.getSetting('active_model') ?? 'Not Selected';
});

final userNameProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  return await settings.getSetting('user_name') ?? 'Admin';
});

final onboardingStatusProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsServiceProvider);
  final status = await settings.getSetting('onboarding_complete');
  return status == 'true';
});
