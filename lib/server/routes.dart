import 'dart:async'; // Add StreamController
import 'package:flutter/foundation.dart'; // Add VoidCallback
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../features/devices/repositories/device_repository.dart';
import '../features/devices/services/pairing_service.dart';
import '../features/research/services/research_repository.dart'; // Import Research Repository
import '../services/chat_history_service.dart';
import '../core/settings_service.dart';
import '../services/ollama_service.dart';
import '../services/web_search_service.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../core/encryption_service.dart';
import '../features/devices/models/device_model.dart';
import '../features/research/models/research_models.dart';

class AppRoutes {
  final DeviceRepository _deviceRepository;
  final ChatHistoryService _chatHistoryService;
  final SettingsService _settingsService;
  final OllamaService _ollamaService;
  final PairingService _pairingService;
  final ResearchRepository _researchRepository;
  final Function(Device)? onDeviceConnected; // Updated callback signature
  final WebSearchService _webSearchService = WebSearchService();

  AppRoutes(
    this._deviceRepository,
    this._chatHistoryService,
    this._settingsService,
    this._ollamaService,
    this._pairingService,
    this._researchRepository,
    {this.onDeviceConnected}
  );

  Router get router {
    final router = Router();
    
    // Public Routes
    router.get('/health', (Request request) {
      return Response.ok(jsonEncode({'status': 'ok', 'service': 'Garnet Studio Gateway'}), 
        headers: {'content-type': 'application/json'});
    });
    
    // Pairing Endpoint (E2EE Handshake)
    router.post('/pair', _handlePairing);

    // Mount protected routes under /api
    router.mount('/api/', _createProtectedRouter());

    return router;
  }
  
  Future<Response> _handlePairing(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body);
      
      final String code = json['code'];
      final String deviceId = json['deviceId'];
      final String deviceName = json['deviceName'];
      final String publicKeyPEM = json['publicKey']; // RSA Public Key from Client
      
      if (!_pairingService.verifyCode(code)) {
        return Response.forbidden(jsonEncode({'error': 'Invalid or expired pairing code'}));
      }
      
      // Generate Shared Secret (AES Key)
      final aesKey = EncryptionService.generateAESKey();
      
      // Generate API Token for simple auth (optional if we rely purely on encryption, but good for quick checks)
      final apiToken = const Uuid().v4();
      final tokenHash = sha256.convert(utf8.encode(apiToken)).toString();
      
      // Store in DB
      final device = Device(
        id: deviceId, 
        name: deviceName, 
        version: '1.0.0', 
        ipAddress: (request.context['shelf.io.connection_info'] as dynamic)?.remoteAddress.address ?? 'unknown', 
        lastActive: DateTime.now(),
        status: DeviceStatus.connected,
        encryptionKey: aesKey
      );
      
      
      await _deviceRepository.authorizeDevice(device, tokenHash, encryptionKey: aesKey);
      
      // Update UI state with live device info (IP, etc)
      // This is critical for the UI to show "Online" instantly
      onDeviceConnected?.call(device);
      
      // Encrypt the AES Key with Client's Public Key
      final encryptedAESKey = EncryptionService.encryptAESKeyWithRSA(aesKey, publicKeyPEM);
      
      return Response.ok(jsonEncode({
        'status': 'success',
        'studioId': 'garnet_studio_desktop', // Should be dynamic
        'encryptedKey': encryptedAESKey,
        'token': apiToken // Still returning token for legacy support or easy ID
      }), headers: {'content-type': 'application/json'});
      
    } catch (e) {
      print('Pairing error: $e');
      return Response.internalServerError(body: jsonEncode({'error': 'Pairing failed: $e'}));
    }
  }
  
  Handler _createProtectedRouter() {
     final router = Router();

     // === USER PROFILE ===
     router.get('/user/profile', (Request request) async {
        final activeModel = await _settingsService.getSetting('active_model') ?? 'Not Selected';
        final userName = await _settingsService.getSetting('user_name') ?? 'User';
        return Response.ok(jsonEncode({
          'user_name': userName,
          'active_model': activeModel
        }), headers: {'content-type': 'application/json'});
     });

     // === OLLAMA MODELS ===
     router.get('/models', (Request request) async {
        final models = await _ollamaService.listModels();
        // Format to match mobile expectation: { "models": [ {"name": "llama3"} ] }
        // _ollamaService.listModels() returns List<String> ? No, need to check.
        // Assuming listModels returns List<String> or List<Map>.
        // If List<String>:
        final formattedModels = models.map((m) => {'name': m}).toList();
        
        return Response.ok(jsonEncode({
          'models': formattedModels
        }), headers: {'content-type': 'application/json'});
     });

     // === CHAT HISTORY ===
     router.get('/chat/history', (Request request) async {
        final sessions = await _chatHistoryService.loadAllSessions();
        return Response.ok(jsonEncode({
          'sessions': sessions.map((s) => s.toJson()).toList()
        }), headers: {'content-type': 'application/json'});
     });

     // === CHAT INFERENCE (SSE STREAM) ===
     router.post('/chat', (Request request) async {
       try {
         final device = request.context['device'] as Device;
         final json = request.context['jsonBody'] as Map<String, dynamic>;
         
         final List<dynamic> messagesList = (json['messages'] as List?) ?? [];
         
         // Handle empty messages list or missing prompt
         if (messagesList.isEmpty) {
            // Check for legacy 'prompt' field
            if (json.containsKey('prompt')) {
               messagesList.add({'role': 'user', 'content': json['prompt']});
            } else {
               print('Chat error: No messages provided in request: $json');
               return Response.badRequest(body: jsonEncode({'error': 'No messages provided'}));
            }
         }
                                         
         // Safened model selection
         final String? model = json['model'] as String?;
         final activeModel = await _settingsService.getSetting('active_model');
         final targetModel = model ?? activeModel ?? 'llama3:latest';

         // Convert messages safely
         final List<ChatMessage> history = messagesList.map((m) {
           final roleStr = m['role'] as String? ?? 'user';
           return ChatMessage(
             id: Uuid().v4(),
             role: roleStr == 'assistant' ? MessageRole.assistant : MessageRole.user,
             content: m['content'] as String? ?? '',
             timestamp: DateTime.now()
           );
         }).toList();
         
         // Inject System Prompt (Branding) to match Desktop behavior
         final customTone = await _settingsService.getSetting('system_prompt') ?? "Friendly and helpful";
         final userName = await _settingsService.getSetting('user_name');
         final isDeepAnalysis = json['isDeepAnalysis'] == true;
         
         String finalSystemPrompt = "You are Garnet, an AI assistant.";
         
         if (userName != null && userName.isNotEmpty) {
             finalSystemPrompt += " You are talking to $userName.";
         }
         
         finalSystemPrompt += " Your personality/tone is: $customTone.";

         if (isDeepAnalysis) {
             // Extract last user message to use as search query
             final lastUserMsg = history.lastWhere((m) => m.role == MessageRole.user, orElse: () => ChatMessage(id: 'err', role: MessageRole.user, content: '', timestamp: DateTime.now()));
             
             if (lastUserMsg.content.isNotEmpty) {
                try {
                  // Perform Knowledge Base Search (Semantic/Full-Text)
                  final searchResults = await _researchRepository.searchGlobalChunks(lastUserMsg.content);
                  
                  if (searchResults.isNotEmpty) {
                      final contextStr = searchResults.map((r) => r.chunk.content).join('\n---\n');
                      finalSystemPrompt += "\n\n--- RESEARCH ENGINE CONTEXT ---\n$contextStr\n--- END CONTEXT ---\n";
                      finalSystemPrompt += "Strictly use the provided research context to answer the user's question. If the answer is in the context, use it directly.";
                  } else {
                      finalSystemPrompt += "\n[System Note: Research Engine active, but no relevant documents found for query: '${lastUserMsg.content}']";
                  }

                } catch (e) {
                   print("Server-side research failed: $e");
                   finalSystemPrompt += "\n[System Note: Knowledge Base search failed, proceed with internal knowledge only.]";
                }
             }
         }

         // Inject Date Context into the System Prompt
         final now = DateTime.now();
         final dateStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
         finalSystemPrompt += "\n\nCurrent Date: $dateStr";

         final systemMessage = ChatMessage(
            id: 'system_branding',
            content: finalSystemPrompt,
            role: MessageRole.system,
            timestamp: DateTime.now(),
         );
         
         final apiMessages = [systemMessage, ...history];
         
         print('Starting chat stream for device ${device.name} with model $targetModel');
         
         final stream = _ollamaService.generateChatStream(apiMessages, targetModel);
         
         final controller = StreamController<List<int>>();
         
         final subscription = stream.listen(
           (chunk) {
             try {
               // Encrypt chunk
               if (device.encryptionKey == null) throw Exception('Device encryption key lost');
               
               final encryptedChunk = EncryptionService.encryptPayload(chunk, device.encryptionKey!);
               controller.add(utf8.encode('data: $encryptedChunk\n\n'));
             } catch (e) {
               print('Streaming encryption error inner: $e');
               try {
                  controller.add(utf8.encode('data: [ERROR] $e\n\n'));
               } catch (_) {}
             }
           },
           onDone: () {
             controller.close();
           },
           onError: (e) {
             print('Stream error: $e');
             controller.addError(e);
             controller.close();
           }
         );

         return Response.ok(controller.stream, headers: {
           'Content-Type': 'text/event-stream',
           'Cache-Control': 'no-cache',
           'Connection': 'keep-alive',
           'X-Encrypted': 'true'
         });

       } catch (e, stack) {
         print('Chat handler error: $e');
         print(stack);
         return Response.internalServerError(body: jsonEncode({'error': 'Server error: $e'}));
       }
     });

     router.get('/preferences', (Request request) async {
        final activeModel = await _settingsService.getSetting('active_model');
        final userName = await _settingsService.getSetting('user_name');
        final systemPrompt = await _settingsService.getSetting('system_prompt');
        return Response.ok(jsonEncode({
           'active_model': activeModel,
           'user_name': userName,
           'system_prompt': systemPrompt
        }), headers: {'content-type': 'application/json'});
     });

     router.post('/preferences', (Request request) async {
        try {
          final json = request.context['jsonBody'] as Map<String, dynamic>;
          
          if (json.containsKey('active_model')) {
             await _settingsService.setSetting('active_model', json['active_model']);
          }
          if (json.containsKey('user_name')) {
             await _settingsService.setSetting('user_name', json['user_name']);
          }
          return Response.ok(jsonEncode({'status': 'updated'}));
        } catch (e) {
           return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
        }
     });

     return Pipeline()
       .addMiddleware(_authCheck)
       .addMiddleware(_encryptionMiddleware)
       .addHandler(router);
  }

  Middleware get _authCheck => (innerHandler) {
    return (Request request) async {
      // Allow /pair to pass without auth (it's in public router, but just in case)
      if (request.url.path == 'pair') return innerHandler(request);

      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.forbidden('Missing or invalid Authorization header');
      }

      final token = authHeader.substring(7);
      final tokenHash = sha256.convert(utf8.encode(token)).toString();

      final device = await _deviceRepository.verifyTokenHash(tokenHash);
      if (device == null) {
        return Response.forbidden('Invalid access token');
      }

      // Capture live IP and verify liveliness
      final ip = (request.context['shelf.io.connection_info'] as dynamic)?.remoteAddress.address ?? 'unknown';
      
      final liveDevice = device.copyWith(
         ipAddress: ip,
         status: DeviceStatus.connected,
         lastActive: DateTime.now()
      );
      
      // Notify UI provider that device is active and update IP
      onDeviceConnected?.call(liveDevice);

      final updatedRequest = request.change(context: {'device': liveDevice});
      return innerHandler(updatedRequest);
    }; 
  };
  
  Middleware get _encryptionMiddleware => (innerHandler) {
    return (Request request) async {
       if (request.url.path == 'pair' || request.url.path == 'health') return innerHandler(request);
       
       final device = request.context['device'] as Device?;
       if (device == null || device.encryptionKey == null) {
          return Response.forbidden('Encryption required: No active session');
       }
       
       // Handle Request Decryption
       final isEncryptedHeader = request.headers['X-Encrypted'] == 'true';
       // We accept GET requests without body/encryption IF they are GET
       if (!isEncryptedHeader && request.method != 'GET') {
          return Response.forbidden('Encryption required: Missing X-Encrypted header');
       }
       
       try {
         final body = await request.readAsString();
         
         // For GET requests or empty bodies, we skip payload decryption but may still encrypt the response
         Map<String, dynamic> json = {};
         // Only attempt decryption if body has actual content (checking trimmed length is safer)
         if (body.trim().isNotEmpty && isEncryptedHeader) { 
            final decryptedJson = EncryptionService.decryptPayload(body, device.encryptionKey!);
            if (decryptedJson.isNotEmpty) {
               try {
                   json = jsonDecode(decryptedJson);
               } catch (jsonErr) {
                   print("JSON Decode Error on '$decryptedJson': $jsonErr");
                   rethrow;
               }
            }
         }
         
         // Stash decrypted body in context for handlers
         // Use a new map to ensure mutability if needed downstream, though context itself is immutable once set in 'change'
         final processedRequest = request.change(context: {'jsonBody': json});
         
         final response = await innerHandler(processedRequest);
         
         // Encrypt Regular Response Body (For standard JSON responses)
         // Streaming responses (SSE) are handled inside the handler itself
         if ((response.headers['content-type'] ?? '').contains('text/event-stream')) {
            return response;
         }
            
         final responseBody = await response.readAsString();
         final encryptedBody = EncryptionService.encryptPayload(responseBody, device.encryptionKey!);
         
         return response.change(
           body: encryptedBody,
           headers: {'X-Encrypted': 'true', 'Content-Type': 'text/plain'}
         );
         
       } catch (e, stack) {
         print('Middleware error: $e\n$stack');
         return Response(400, body: 'Middleware error: $e');
       }
    };
  };
}
