import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database.dart';
import '../models/device_model.dart';

class DeviceRepository {
  final DatabaseService _dbService;

  DeviceRepository(this._dbService);

  Future<List<Device>> getAuthorizedDevices() async {
    final db = await _dbService.database;
    final results = await db.query('authorized_devices', orderBy: 'last_active DESC');
    return results.map((map) => Device.fromDb(map)).toList();
  }

  Future<void> authorizeDevice(Device device, String tokenHash, {String? encryptionKey}) async {
    final db = await _dbService.database;
    await db.insert('authorized_devices', {
      'id': device.id,
      'device_name': device.name,
      'token_hash': tokenHash,
      'encryption_key': encryptionKey,
      'last_active': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateLastActive(String deviceId) async {
    final db = await _dbService.database;
    await db.update(
      'authorized_devices',
      {'last_active': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> revokeDevice(String deviceId) async {
    final db = await _dbService.database;
    await db.delete('authorized_devices', where: 'id = ?', whereArgs: [deviceId]);
  }

  Future<Device?> verifyTokenHash(String tokenHash) async {
    final db = await _dbService.database;
    final results = await db.query(
      'authorized_devices',
      where: 'token_hash = ?',
      whereArgs: [tokenHash],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      final device = Device.fromDb(results.first);
      // Update last active
      updateLastActive(device.id);
      return device;
    }
    return null;
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(DatabaseService());
});
