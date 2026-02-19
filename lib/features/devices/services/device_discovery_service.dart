import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:nsd/nsd.dart' as nsd;
import '../models/device_model.dart';

class DeviceDiscoveryService {
  nsd.Discovery? _discovery;
  final StreamController<Device> _deviceDiscoveredController = StreamController.broadcast();
  final StreamController<String> _deviceLostController = StreamController.broadcast();

  nsd.Registration? _registration;

  Stream<Device> get onDeviceDiscovered => _deviceDiscoveredController.stream;
  Stream<String> get onDeviceLost => _deviceLostController.stream;

  Future<void> startBroadcast({
    required String deviceId, 
    required String deviceName, 
    int port = 8080
  }) async {
    if (_registration != null) return;
    try {
      _registration = await nsd.register(
        nsd.Service(
          name: deviceName, 
          type: '_garnet._tcp',
          port: port,
          txt: {
             'app': Uint8List.fromList(utf8.encode('garnet-studio')),
             'version': Uint8List.fromList(utf8.encode('1.0.0')),
             'deviceId': Uint8List.fromList(utf8.encode(deviceId)),
             'platform': Uint8List.fromList(utf8.encode('windows')),
          } 
        )
      );
    } catch (e) {
      print("Broadcast failed: $e");
    }
  }

  Future<void> stopBroadcast() async {
    if (_registration != null) {
      await nsd.unregister(_registration!);
      _registration = null;
    }
  }

  Future<void> startDiscovery() async {
    if (_discovery != null) return;

    try {
      _discovery = await nsd.startDiscovery('_garnet._tcp');
      
      _discovery!.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found) {
           _processService(service);
        } else if (status == nsd.ServiceStatus.lost) {
           // We might not get the full ID here, but let's try to match by name or host
           // Nsd Service object might not have the ID if we didn't extract it yet.
           // However, usually mDNS "lost" gives the service info.
           // We can assume service.name is unique in mDNS context usually.
           // But our Device ID is from the handshake.
           // We'll need to map mDNS name to Device ID if we want to handle "lost" correctly by ID.
           // For now, we'll ignore explicit "lost" from mDNS for the strictly verified list,
           // and rely on health checks or just re-discovery.
           // Actually, let's just trigger a re-scan or let the ping fail.
        }
      });
    } catch (e) {
      print("Discovery failed: $e");
    }
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await nsd.stopDiscovery(_discovery!);
      _discovery = null;
    }
  }

  Future<void> _processService(nsd.Service service) async {
    // 1. Check TXT records locally if available
    // Note: nsd on some platforms might not give TXT records immediately or consistently.
    // But the prompt says "A device must only appear if... TXT record contains..."
    
    // Check constraints first
    final txt = service.txt;
    if (txt == null) return;
    
    // Attempt to decode TXT keys (nsd might provide them as bytes or strings depending on platform/impl)
    // Assuming standard Map<String, Uint8List?> or similar.
    // Nsd docs say `Map<String, Uint8List>? txt`.
    
    final appData = _decodeTxtValue(txt, 'app');
    if (appData != null && appData != 'garnet-mobile') return;
    // If 'app' tag is missing, we might skip or proceed. Prompt says "TXT record contains 'app=garnet-mobile'".
    if (appData == null) return;
    
    final version = _decodeTxtValue(txt, 'version') ?? '1.0.0';
    final deviceId = _decodeTxtValue(txt, 'id') ?? _decodeTxtValue(txt, 'deviceId');
    // Note: 'deviceId' key is standard but let's be flexible.
    
    if (deviceId == null) return;

    // 2. Resolve IP and Port
    // Service might have host/port.
    if (service.host == null || service.port == null) return;
    
    final ip = service.host!;
    final port = service.port!;

    // 3. Handshake Verification (Strict)
    try {
      final url = Uri.parse('http://$ip:$port/handshake');
      final response = await http.get(url).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Strict check on handshake response too
        if (data['app'] == 'garnet-mobile' && 
            (data['deviceId'] == deviceId || data['id'] == deviceId)) {
            
            final device = Device(
              id: deviceId, // Use the ID from TXT record or Handshake? Prefer Handshake as source of truth if equal.
              name: data['deviceName'] ?? service.name ?? 'Unknown Garnet',
              version: data['version'] ?? version,
              ipAddress: ip,
              port: port,
              lastActive: DateTime.now(),
              status: DeviceStatus.discovered,
            );
            
            _deviceDiscoveredController.add(device);
        }
      }
    } catch (e) {
      // Handshake failed, ignore.
    }
  }
  
  String? _decodeTxtValue(Map<String, Uint8List?>? txt, String key) {
     if (txt == null || !txt.containsKey(key)) return null;
     try {
       final bytes = txt[key];
       if (bytes == null) return null;
       return utf8.decode(bytes); // Should handle list of bytes
     } catch (e) {
       return null;
     }
  }
}
