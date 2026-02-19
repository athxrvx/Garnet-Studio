import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/devices/repositories/device_repository.dart';
import '../models/device_model.dart';

class DevicesNotifier extends StateNotifier<List<DeviceModel>> {
  final DeviceRepository _repository;

  DevicesNotifier(this._repository) : super([]) {
    refresh();
  }

  Future<void> refresh() async {
    state = await _repository.getAllDevices();
  }

  Future<void> addDevice(DeviceModel device) async {
    // For manual add, we don't have a token hash from pairing, 
    // so we might generate a placeholder or not use auth for manual IPs.
    // This connects the UI "Add Device" to SQLite.
    await _repository.addDevice(device.id, device.name, 'manual_entry_hash');
    await refresh();
  }

  Future<void> removeDevice(String id) async {
    await _repository.removeDevice(id);
    await refresh();
  }

  Future<void> updateDevice(DeviceModel device) async {
    // Update logic for DB if needed
    // For now, DB only stores ID/Name/Token.
    // In formatting a real app, we'd have a full device table.
    // We just refresh the list.
    await refresh(); 
  }
}

final devicesProvider = StateNotifierProvider<DevicesNotifier, List<DeviceModel>>((ref) {
  final repo = ref.watch(deviceRepositoryProvider);
  return DevicesNotifier(repo);
});
