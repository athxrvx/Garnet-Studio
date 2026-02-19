import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/device.dart';
import '../models/chat_message.dart';
import 'ollama_service.dart';

class PairingRequest {
  final String deviceName;
  final String deviceId;
  final String ip;
  final String code;
  final DateTime expiresAt;
  final Completer<bool> completer;

  PairingRequest({
    required this.deviceName,
    required this.deviceId,
    required this.ip,
    required this.code,
    required this.expiresAt,
    required this.completer,
  });
}

class LocalServerService {
  HttpServer? _server;
  final OllamaService _ollamaService = OllamaService();
  final int _port = AppConstants.defaultServerPort;
  
  // Storage for devices (In-memory for now, should be persisted)
  final Map<String, Device> _authorizedDevices = {};
  
  // Active pairing requests
  final Map<String, PairingRequest> _pendingPairings = {}; // Key is the generated code
  
  // Stream controller for UI to handle pairing requests
  final _pairingRequestController = StreamController<PairingRequest>.broadcast();
  Stream<PairingRequest> get pairingRequestStream => _pairingRequestController.stream;

  Future<void> start() async {
    final router = Router();
    
    // Pairing Endpoint
    router.post('/pair/request', _handlePairingRequest);
    
    // Auth Check Endpoint
    router.post('/pair/verify', _handlePairingVerification);
    
    // WebSocket for Chat
    router.get('/ws', (Request request) {
      if (!_isAuthenticated(request)) {
        return Response.forbidden('Unauthorized');
      }
      return webSocketHandler((webSocket, _) => _handleWebSocket(webSocket))(request);
    });

    final handler = Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router);

    // Using 0.0.0.0 to listen on all interfaces
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    print('Server listening on port ${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  // --- Handlers ---

  Future<Response> _handlePairingRequest(Request request) async {
    try {
      final content = await request.readAsString();
      final data = jsonDecode(content);
      
      final deviceName = data['deviceName'];
      final deviceId = data['deviceId'];
      // Get IP from connection info if possible, or request body
      final ip = (request.context['shelf.io.connection_info'] as HttpConnectionInfo?)?.remoteAddress.address ?? 'unknown';

      if (deviceName == null || deviceId == null) {
        return Response.badRequest(body: 'Missing deviceName or deviceId');
      }

      // Generate 6-digit code
      final code = _generatePairingCode();
      final completer = Completer<bool>();
      
      final pairingReq = PairingRequest(
        deviceName: deviceName,
        deviceId: deviceId,
        ip: ip,
        code: code,
        expiresAt: DateTime.now().add(const Duration(seconds: 60)),
        completer: completer,
      );

      _pendingPairings[code] = pairingReq;
      
      // Notify UI
      _pairingRequestController.add(pairingReq);
      
      // We return the code to the mobile device so it can display it or use it?
      // "Mobile enters the 6-digit code." -> implies User reads from Studio and enters on Mobile.
      // But prompt says: "Studio displays popup... Mobile enters the 6-digit code."
      // Wait, if Studio displays popup "Code: 123456", and User enters "123456" on Mobile,
      // then Mobile needs to send "123456" to Studio.
      // So Studio generates the code, shows it to User. Mobile DOES NOT know the code yet.
      // Mobile sends /pair/verify with the code user typed.
      
      // So we return "Pending Approval" or just "OK" to /pair/request.
      // Mobile then prompts user for code.
      
      return Response.ok(jsonEncode({
        'status': 'awaiting_code',
        'message': 'Please enter the code displayed on Garnet Studio'
      }));

    } catch (e) {
      return Response.internalServerError(body: '$e');
    }
  }
  
  Future<Response> _handlePairingVerification(Request request) async {
    try {
      final content = await request.readAsString();
      final data = jsonDecode(content);
      final code = data['code'];
      final deviceName = data['deviceName'];
      final deviceId = data['deviceId']; // Mobile should send this again to confirm identity
      
      if (code == null) return Response.badRequest(body: 'Missing code');
      
      final pending = _pendingPairings[code];
      
      if (pending == null) {
        return Response.forbidden('Invalid or expired code');
      }
      
      // Here is the logic: 
      // User must have clicked "Approve" on Studio for this specific request.
      // Wait for approval.
      
      if (!pending.completer.isCompleted) {
         // UI hasn't approved yet. Mobile is too fast or UI is slow.
         // We can wait a bit or fail.
         try {
           final approved = await pending.completer.future.timeout(const Duration(seconds: 30));
           if (!approved) return Response.forbidden('Pairing rejected by user');
         } catch (e) {
           return Response.forbidden('Approval timeout');
         }
      }
      
      // Code matched and approved.
      // Generate Token
      final token = const Uuid().v4(); 
      // Hashing token for storage
      final bytes = utf8.encode(token);
      final digest = sha256.convert(bytes);
      final tokenHash = digest.toString();
      
      final newDevice = Device(
        id: deviceId ?? 'unknown',
        name: deviceName ?? 'Unknown Device',
        ip: pending.ip,
        tokenHash: tokenHash,
        lastUsed: DateTime.now(),
        dateAdded: DateTime.now(),
      );
      
      _authorizedDevices[deviceId] = newDevice;
      _pendingPairings.remove(code);
      
      return Response.ok(jsonEncode({
        'token': token, // Send RAW token to mobile
        'message': 'Pairing successful'
      }));

    } catch (e) {
      return Response.internalServerError(body: '$e');
    }
  }

  void approvePairing(String code) {
    if (_pendingPairings.containsKey(code)) {
      if (!_pendingPairings[code]!.completer.isCompleted) {
         _pendingPairings[code]!.completer.complete(true);
      }
    }
  }
  
  void rejectPairing(String code) {
    if (_pendingPairings.containsKey(code)) {
        if (!_pendingPairings[code]!.completer.isCompleted) {
            _pendingPairings[code]!.completer.complete(false);
        }
        _pendingPairings.remove(code);
    }
  }

  void _handleWebSocket(WebSocketChannel webSocket) {
    webSocket.stream.listen((message) async {
       try {
         final data = jsonDecode(message);
         if (data['type'] == 'chat') {
            final prompt = data['prompt'];
            final model = data['model'] ?? 'llama3:latest';
            
            // Stream back to mobile
            final stream = _ollamaService.generateChatStream([
              ChatMessage(id: 'mob', content: prompt, role: MessageRole.user, timestamp: DateTime.now())
            ], model);
            
            await for (final chunk in stream) {
              webSocket.sink.add(jsonEncode({
                'type': 'chunk',
                'content': chunk
              }));
            }
            webSocket.sink.add(jsonEncode({'type': 'done'}));
         }
       } catch (e) {
         print("WS Error: $e");
       }
    });
  }

  bool _isAuthenticated(Request request) {
    // Basic Bearer Token check
    // In real app, check 'Authorization' header
    // shelf_web_socket might put headers in context or we check upgrade request
    // For now, let's assume passed in query param or header
    final authHeader = request.headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) return false;
    
    final token = authHeader.substring(7);
     final bytes = utf8.encode(token);
    final digest = sha256.convert(bytes);
    final tokenHash = digest.toString();
    
    return _authorizedDevices.values.any((d) => d.tokenHash == tokenHash);
  }

  String _generatePairingCode() {
    var rng = Random();
    return (rng.nextInt(900000) + 100000).toString();
  }
}
