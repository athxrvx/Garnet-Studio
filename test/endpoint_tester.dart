// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/api.dart'; // Add this import for basic types
import 'package:garnet_studio/core/encryption_service.dart'; // Uses project's service

// --- CONFIGURATION ---
const String baseUrl = 'http://localhost:8787';

void main() async {
  print('=== Garnet Studio Data Inspector ===');
  print('Target: $baseUrl');

  // 1. Health Check
  print('\n--- [1] GET /health (Public) ---');
  try {
    final healthRes = await http.get(Uri.parse('$baseUrl/health'));
    print('Status: ${healthRes.statusCode}');
    print('Raw Body: ${healthRes.body}'); // Should see pure JSON
    if (healthRes.statusCode != 200) exit(1);
  } catch (e) {
    print('Error: $e');
    exit(1);
  }

  // 2. Generate Keys 
  print('\n--- [2] Generating Keys ---');
  final rsaPair = generateRSAKeyPair();
  final publicKeyPem = encodePublicKeyToPem(rsaPair.publicKey as RSAPublicKey);
  // print('Generated Public Key:\n$publicKeyPem');

  // 3. Pairing
  print('\n--- [3] POST /pair (Handshake) ---');
  stdout.write('👉 Enter Pairing Code: ');
  final code = stdin.readLineSync()?.trim() ?? '';
  
  if (code.isEmpty) exit(1);

  final pairRes = await http.post(
    Uri.parse('$baseUrl/pair'),
    body: jsonEncode({
      "code": code,
      "deviceId": "dart-inspector",
      "deviceName": "Inspector Tool",
      "publicKey": publicKeyPem
    })
  );

  print('Status: ${pairRes.statusCode}');
  print('Raw Body: ${pairRes.body}'); 
  
  if (pairRes.statusCode != 200) {
    print('Expected {"status": "success", "encryptedKey": "...", "token": "..."}');
    exit(1);
  }

  final pairData = jsonDecode(pairRes.body);
  final token = pairData['token'];
  final encryptedAesKey = pairData['encryptedKey'];
  
  print('\n[Decryption Step]');
  print('Decrypted AES Key ...');
  final aesKey = decryptRSA(encryptedAesKey, rsaPair.privateKey as RSAPrivateKey);
  print('🔑 Shared Secret: $aesKey');

  // 5. Test Encrypted Endpoint
  print('\n--- [4] GET /api/user/profile (Encrypted Data) ---');
  final profileRes = await http.get(
    Uri.parse('$baseUrl/api/user/profile'),
    headers: { 'Authorization': 'Bearer $token', 'X-Encrypted': 'true' }
  );
  
  print('Status: ${profileRes.statusCode}');
  print('Raw Encrypted Body (BASE64):');
  print(profileRes.body);
  
  if (profileRes.statusCode == 200) {
      final decrypted = EncryptionService.decryptPayload(profileRes.body, aesKey);
      print('\nDECRYPTED: $decrypted');
  }

  // 5b. Test Models Endpoint
  print('\n--- [4.5] GET /api/models (Encrypted Data) ---');
  final modelsRes = await http.get(
    Uri.parse('$baseUrl/api/models'),
    headers: { 'Authorization': 'Bearer $token', 'X-Encrypted': 'true' }
  );
  
  if (modelsRes.statusCode == 400) {
      print('[ERROR] Server returned 400: ${modelsRes.body}');
  } else {
      print('Status: ${modelsRes.statusCode}');
      print('Raw Encrypted Body (BASE64):');
      print(modelsRes.body);
  }
  
  if (modelsRes.statusCode == 200) {
      final decrypted = EncryptionService.decryptPayload(modelsRes.body, aesKey);
      print('\nDECRYPTED MODELS: $decrypted');
  }

  // 6. Test Chat Stream
  print('\n--- [5] POST /api/chat (Encrypted Stream) ---');
  // ... (Keep existing stream logic but print raw chunks) ...
     final client = http.Client();
     final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
     request.headers['Authorization'] = 'Bearer $token';
     request.headers['X-Encrypted'] = 'true';
     
     final jsonPayload = jsonEncode({
       "messages": [ {"role": "user", "content": "Hi"} ],
       "model": "llama3.2:1b"
     });
     
     request.body = EncryptionService.encryptPayload(jsonPayload, aesKey);
     final streamedRes = await client.send(request);
     
     if (streamedRes.statusCode == 200) {
       print('Streaming... (Receiving Encrypted Chunks)');
       await for (final chunk in streamedRes.stream.transform(utf8.decoder)) {
          // Print raw SSE format
          final lines = chunk.split('\n');
           for (final line in lines) {
             if (line.startsWith('data: ')) {
               var payload = line.substring(6).trim();
               if (payload.isNotEmpty) {
                 print('[CHUNK] $payload');
                 try {
                   final text = EncryptionService.decryptPayload(payload, aesKey);
                   print('   -> "$text"');
                 } catch (e) { }
               }
             }
           }
       }
     }
}


// --- RSA UTILS ---
AsymmetricKeyPair<PublicKey, PrivateKey> generateRSAKeyPair() {
  final secureRandom = pc.FortunaRandom();
  final seed = Platform.isWindows ? 
      List<int>.generate(32, (_) => Random.secure().nextInt(255)) : 
      File('/dev/urandom').readAsBytesSync().sublist(0, 32);
      
  secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seed)));
  
  final keyGen = pc.RSAKeyGenerator()
    ..init(pc.ParametersWithRandom(
      pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
      secureRandom
    ));
    
  return keyGen.generateKeyPair();
}

String encodePublicKeyToPem(RSAPublicKey publicKey) {
  var algorithmSeq = ASN1Sequence();
  var algorithmAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01]));
  var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x05, 0x00]));
  algorithmSeq.add(algorithmAsn1Obj);
  algorithmSeq.add(paramsAsn1Obj);

  var publicKeySeq = ASN1Sequence();
  publicKeySeq.add(ASN1Integer(publicKey.modulus!));
  publicKeySeq.add(ASN1Integer(publicKey.exponent!));
  
  var publicKeySeqBitString = ASN1BitString(Uint8List.fromList(publicKeySeq.encodedBytes));

  var topLevelSeq = ASN1Sequence();
  topLevelSeq.add(algorithmSeq);
  topLevelSeq.add(publicKeySeqBitString);
  
  var dataBase64 = base64.encode(topLevelSeq.encodedBytes);
  return """-----BEGIN PUBLIC KEY-----
$dataBase64
-----END PUBLIC KEY-----""";
}

// Using 'encrypt' package for RSA decryption is easier if we formatting is right, 
// but manual implementation with standard PointyCastle is often safer for raw bytes.
String decryptRSA(String encryptedBase64, RSAPrivateKey privateKey) {
  // Use PKCS1Encoding instead of OAEPEncoding as 'encrypt' package (used by server) defaults to PKCS1 for RSA
  final cipher = pc.PKCS1Encoding(pc.RSAEngine())
    ..init(false, pc.PrivateKeyParameter<RSAPrivateKey>(privateKey));
    
  final encryptedBytes = base64.decode(encryptedBase64);
  final decryptedBytes = cipher.process(Uint8List.fromList(encryptedBytes));
  
  return utf8.decode(decryptedBytes);
}

// Minimal ASN1 implementation for PEM encoding
class ASN1Object {
  int tag;
  Uint8List? value;
  ASN1Object(this.tag);
  ASN1Object.fromBytes(Uint8List bytes) : tag = bytes[0], value = bytes.sublist(2); // Simplified
  
  Uint8List get encodedBytes {
    var val = value ?? Uint8List(0);
    var lenBytes = _encodeLength(val.length);
    return Uint8List.fromList([tag, ...lenBytes, ...val]);
  }
}

class ASN1Integer extends ASN1Object {
  ASN1Integer(BigInt i) : super(0x02) {
    var raw = _encodeBigInt(i);
    value = raw;
  }
}

class ASN1Sequence extends ASN1Object {
  List<ASN1Object> elements = [];
  ASN1Sequence() : super(0x30);
  void add(ASN1Object o) => elements.add(o);
  
  @override
  Uint8List get encodedBytes {
    var content = <int>[];
    for (var e in elements) content.addAll(e.encodedBytes);
    var lenBytes = _encodeLength(content.length);
    return Uint8List.fromList([tag, ...lenBytes, ...content]);
  }
}
class ASN1BitString extends ASN1Object {
  ASN1BitString(Uint8List bytes) : super(0x03) {
    value = Uint8List.fromList([0x00, ...bytes]); // 0x00 padding
  }
}
Uint8List _encodeBigInt(BigInt number) {
  var hex = number.toRadixString(16);
  if (hex.length % 2 != 0) hex = '0$hex';
  var bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  if (bytes[0] >= 128) bytes.insert(0, 0); // Sign bit
  return Uint8List.fromList(bytes);
}
List<int> _encodeLength(int length) {
  if (length < 128) return [length];
  var hex = length.toRadixString(16);
  if (hex.length % 2 != 0) hex = '0$hex';
  var bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  return [0x80 | bytes.length, ...bytes];
}
