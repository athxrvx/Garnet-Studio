import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../services/device_discovery_service.dart';
import '../repositories/device_repository.dart';
import '../services/pairing_service.dart';

// Services
final deviceDiscoveryServiceProvider = Provider((ref) => DeviceDiscoveryService());

// State Classes
class DeviceManagerState {
  final List<Device> discoveredDevices;
  final List<Device> authorizedDevices;
  final bool isScanning;
  final String? currentPairingCode; // Add pairing code to state

  DeviceManagerState({
    this.discoveredDevices = const [],
    this.authorizedDevices = const [],
    this.isScanning = false,
    this.currentPairingCode,
  });

  DeviceManagerState copyWith({
    List<Device>? discoveredDevices,
    List<Device>? authorizedDevices,
    bool? isScanning,
    String? currentPairingCode,
  }) {
    return DeviceManagerState(
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      authorizedDevices: authorizedDevices ?? this.authorizedDevices,
      isScanning: isScanning ?? this.isScanning,
      currentPairingCode: currentPairingCode ?? this.currentPairingCode,
    );
  }
}

// Notifier
class DeviceManagerNotifier extends StateNotifier<DeviceManagerState> {
  final DeviceDiscoveryService _discoveryService;
  final DeviceRepository _repository;
  final PairingService _pairingService; // Inject PairingService

  DeviceManagerNotifier(this._discoveryService, this._repository, this._pairingService) : super(DeviceManagerState()) {
    _loadAuthorizedDevices();
    _startDiscovery();
    _startBroadcasting();
    
    // Listen for new authorized devices (e.g. from API)
    // The repository should ideally have a stream, but for now we'll poll or refresh manually.
    // A simple timer could work, or rely on force refresh.
  }

  void _startBroadcasting() {
     // Generate or fetch persistent ID for this Desktop instance
     const desktopDeviceId = "garnet_studio_desktop_01";
     const desktopName = "Garnet Desktop";
     
     _discoveryService.startBroadcast(
       deviceId: desktopDeviceId, 
       deviceName: desktopName,
       port: 8787 // Correct port
     );
  }

  Future<void> _loadAuthorizedDevices() async {
    final dbDevices = await _repository.getAuthorizedDevices();
    
    // IMPORTANT: Merge with existing state to preserve 'connected' status and IPs
    // because the DB only stores static info and 'offline' state by default.
    
    final mergedDevices = dbDevices.map((dbDevice) {
       final existing = state.authorizedDevices
          .cast<Device?>() // Cast for firstWhereOrNull logic
          .firstWhere((d) => d!.id == dbDevice.id, orElse: () => null);
       
       if (existing != null && existing.status == DeviceStatus.connected) {
         // Keep the live status and IP from memory
         return dbDevice.copyWith(
           status: DeviceStatus.connected,
           ipAddress: existing.ipAddress,
           version: existing.version.isNotEmpty ? existing.version : dbDevice.version,
           // Ensure key is preserved (DB has authoritative key usually, but if memory has it, fine)
           encryptionKey: dbDevice.encryptionKey ?? existing.encryptionKey
         );
       }
       return dbDevice;
    }).toList();

    state = state.copyWith(authorizedDevices: mergedDevices);
  }

  void refreshDevices() => _loadAuthorizedDevices(); // Public refresh

  void handleDeviceConnection(Device device) {
     final index = state.authorizedDevices.indexWhere((d) => d.id == device.id);
     
     if (index != -1) {
       // Update existing device with live network info
       final updatedList = List<Device>.from(state.authorizedDevices);
       updatedList[index] = updatedList[index].copyWith(
         status: DeviceStatus.connected,
         ipAddress: device.ipAddress,
         version: device.version.isNotEmpty ? device.version : updatedList[index].version,
         lastActive: DateTime.now(),
         // Don't overwrite key if null (though it shouldn't be)
       );
       
       state = state.copyWith(authorizedDevices: updatedList);
       _repository.updateLastActive(device.id);
     } else {
       // If not in list yet (race condition with DB load?), reload
       _loadAuthorizedDevices().then((_) {
          // Try update again after reload
          handleDeviceConnection(device);
       });
     }
  }

  void _startDiscovery() {
    state = state.copyWith(isScanning: true);
    _discoveryService.startDiscovery();
    
    _discoveryService.onDeviceDiscovered.listen((device) {
       _handleDiscoveredDevice(device);
    });
  }
  
  void _handleDiscoveredDevice(Device device) {
    final isAuthorized = state.authorizedDevices.any((d) => d.id == device.id);
    
    if (isAuthorized) {
       final existing = state.authorizedDevices.firstWhere((d) => d.id == device.id);
       // Only update if IP changed to minimize state churn
       if (existing.ipAddress != device.ipAddress || existing.port != device.port || existing.status != DeviceStatus.connected) {
          final updatedAuthorized = state.authorizedDevices.map((d) {
           if (d.id == device.id) {
             return d.copyWith(
               status: DeviceStatus.connected,
               ipAddress: device.ipAddress,
               port: device.port,
               lastActive: DateTime.now()
             );
           }
           return d;
         }).toList();
         state = state.copyWith(authorizedDevices: updatedAuthorized);
         _repository.updateLastActive(device.id);
       }
    } else {
       if (!state.discoveredDevices.any((d) => d.id == device.id)) {
          state = state.copyWith(
            discoveredDevices: [...state.discoveredDevices, device]
          );
       }
    }
  }

  // Pairing Flow - Updated for E2EE
  // Desktop generates code, User enters on Mobile
  String initiatePairing() {
     final code = _pairingService.generatePairingCode();
     state = state.copyWith(currentPairingCode: code);
     return code;
  }
  
  // Confirmed by API, not UI (usually). 
  // But if UI explicitly wants to check status, it can poll API or check DB via refresh.
  
  void clearPairingCode() {
    state = state.copyWith(currentPairingCode: null);
  }

  Future<void> revokeDevice(String deviceId) async {
     await _repository.revokeDevice(deviceId);
     _loadAuthorizedDevices(); // Auto refresh
  }
}

final deviceManagerProvider = StateNotifierProvider<DeviceManagerNotifier, DeviceManagerState>((ref) {
  final discovery = ref.watch(deviceDiscoveryServiceProvider);
  final repository = ref.watch(deviceRepositoryProvider);
  final pairingService = ref.watch(pairingServiceProvider); // Watch new service
  return DeviceManagerNotifier(discovery, repository, pairingService);
});

final connectedDevicesCountProvider = Provider<AsyncValue<int>>((ref) {
  final state = ref.watch(deviceManagerProvider);
  // We count authorized devices that are effectively "known". 
  // If you want only "online" ones, filter by status == DeviceStatus.connected
  return AsyncValue.data(state.authorizedDevices.length);
});
