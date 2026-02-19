import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:nsd/nsd.dart'; // Import NSD
import 'routes.dart';
import '../features/devices/repositories/device_repository.dart';
import '../features/devices/models/device_model.dart';
import '../services/chat_history_service.dart';
import '../core/settings_service.dart';
import '../features/devices/services/pairing_service.dart';
import '../services/ollama_service.dart';
import '../features/chat/ollama_provider.dart';
import '../core/constants/app_constants.dart';
import '../features/devices/providers/device_provider.dart'; // Import Device Provider
import '../features/dashboard/providers/system_log_provider.dart'; // Import System Log Provider
import '../features/research/services/research_repository.dart'; // Import Research Repository
import '../features/research/providers/research_provider.dart'; // Import Research Provider Source

import 'dart:convert'; // For utf8 encoding if needed
import 'dart:typed_data'; // For Uint8List

class GatewayService extends StateNotifier<bool> {
  HttpServer? _server;
  Registration? _registration; // For mDNS
  final int _port = AppConstants.defaultServerPort; 
  final DeviceRepository _deviceRepository;
  final ChatHistoryService _chatHistoryService;
  final SettingsService _settingsService;
  final OllamaService _ollamaService;
  final PairingService _pairingService;
  final ResearchRepository _researchRepository;
  final Function(Device)? onDeviceConnected;

final SystemLogNotifier _systemLog;

  GatewayService(
    this._deviceRepository,
    this._chatHistoryService,
    this._settingsService,
    this._ollamaService,
    this._pairingService,
    this._researchRepository,
    this._systemLog,
    {this.onDeviceConnected}
  ) : super(false) {
    _initAutoStart();
  }

  bool get isRunning => state;
  int get port => _port;

  Future<void> _initAutoStart() async {
    final autoStart = await _settingsService.getSetting('gateway_server_autostart');
    // Default to true if setting doesn't exist
    if (autoStart == null || autoStart == 'true') {
      await startServer();
    }
  }

  Future<void> startServer() async {
    if (state) return;

    try {
      final router = AppRoutes(
        _deviceRepository,
        _chatHistoryService,
        _settingsService,
        _ollamaService,
        _pairingService,
        _researchRepository,
        onDeviceConnected: onDeviceConnected
      ).router;
      
      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addHandler(router);

      // Listen on ANY interface (0.0.0.0)
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      state = true;
      print('Gateway Service running on port ${_server!.port}');
      _systemLog.addLog('Gateway Service started on port ${_server!.port}', level: LogLevel.success);

      // Start mDNS Discovery (Like LocalSend)
      await _startDiscoveryService();
      
    } catch (e, stack) {
      print('Failed to start server: $e\n$stack');
      _systemLog.addLog('Failed to start server: $e', level: LogLevel.error);
      state = false;
    }
  }

  Future<void> _startDiscoveryService() async {
    try {
      final hostname = Platform.localHostname;
      
      // Register service _garnet._tcp
      // This allows mobile apps to find us without typing IP
      _registration = await register(
        Service(
          name: 'Garnet Studio', // Can optionally append hostname
          type: AppConstants.serviceType,
          port: _port,
          txt: {
            'app': Uint8List.fromList(utf8.encode('garnet-studio')),
            'deviceName': Uint8List.fromList(utf8.encode(hostname)),
            'deviceId': Uint8List.fromList(utf8.encode(const Uuid().v4())),
            'version': Uint8List.fromList(utf8.encode('1.0.0'))
          }
        ),
      );
      print('mDNS Service Registered: ${_registration?.service.name}');
      _systemLog.addLog('mDNS Service Registered: ${_registration?.service.name}', level: LogLevel.info);
    } catch (e) {
      print('Failed to register mDNS service: $e');
      _systemLog.addLog('mDNS registration failed: $e', level: LogLevel.warn);
      // Non-fatal, server still runs
    }
  }

  Future<void> stopServer() async {
    if (!state) return;
    
    // Stop mDNS
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }

    await _server?.close();
    _server = null;
    state = false;
    print('Gateway Service stopped');
    _systemLog.addLog('Gateway Service stopped', level: LogLevel.warn);
  }
}

final gatewayServiceProvider = StateNotifierProvider<GatewayService, bool>((ref) {
  final deviceRepository = ref.watch(deviceRepositoryProvider);
  final chatHistory = ref.watch(chatHistoryServiceProvider);
  final settings = ref.watch(settingsServiceProvider);
  final ollama = ref.watch(ollamaServiceProvider);
  final pairing = ref.watch(pairingServiceProvider);
  final systemLog = ref.read(systemLogProvider.notifier);
  final researchRepo = ref.watch(researchRepositoryProvider);

  return GatewayService(
    deviceRepository,
    chatHistory,
    settings,
    ollama,
    pairing,
    researchRepo,
    systemLog,
    onDeviceConnected: (device) {
       ref.read(deviceManagerProvider.notifier).handleDeviceConnection(device);
    }, 
  );
});
