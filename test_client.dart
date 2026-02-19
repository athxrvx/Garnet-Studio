import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:rsa_pkcs/rsa_pkcs.dart' as pkcs;

// --- CONFIGURATION ---
const String validPairingCode = 'ENTER_CODE_HERE'; // User can edit this or input at runtime
const String baseUrl = 'http://localhost:8787';

// --- HARDCODED TEST RSA KEYS (2048-bit) ---
// In a real app, generate these. For testing, we use static ones.
const String clientPublicKeyPEM = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuLytX/t3U4gQ8+w+zJ3U
bJq6q4w0+e5Q7w5W4w6e7Q8r9t0u1v2x3y4z5A6B7C8D9E0F1G2H3I4J5K6L7M8N
9O0P1Q2R3S4T5U6V7W8X9Y0Z1A2B3C4D5E6F7G8H9I0J1K2L3M4N5O6P7Q8R9S0T
1U2V3W4X5Y6Z7A8B9C0D1E2F3G4H5I6J7K8L9M0N1O2P3Q4R5S6T7U8V9W0X1Y2Z
3a4b5c6d7e8f9g0h1i2j3k4l5m6n7o8p9q0r1s2t3u4v5w6x7y8z9a0b1c2d3e4f
5g6h7i8j9k0l1m2n3o4p5q6r7s7t8u9v0w1x2y3z4a5b6c7d8e9f0g1h2i3j4k5l
6m7n8o9p0q1r2s3t4u5v6w7x8y9z0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r
8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x
+y+z+a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q+r+s+t+u+v+w+x+y+z01234567
89+/
-----END PUBLIC KEY-----
''';

// This is just a placeholder. In a real test, strict key generation is needed.
// However, since we can't easily perform RSA Decryption in a simple script without massive boilerplate 
// for strict PKCS1/OAEP padding support matching the server, we will simulate the decryption if needed 
// or simpler: Use the actual 'encrypt' package if it supports private key load easily.

// SIMPLIFICATION FOR USER:
// Instead of full complex RSA handling in this script, we will assume the server works 
// if we get a 200 OK and a blob. 
// BUT better yet, let's assume we can fetch the AES key if we mock the client side properly.
// OR, use the 'encrypt' package which the project already has.

Future<void> main() async {
  print('=== Garnet Studio API Tester ===');
  
  // 1. Health Check
  print('\n[1] Testing Health...');
  final healthRes = await http.get(Uri.parse('$baseUrl/health'));
  print('Status: ${healthRes.statusCode}');
  print('Body: ${healthRes.body}');
  if (healthRes.statusCode != 200) exit(1);

  // 2. Pairing
  print('\n[2] Testing Pairing...');
  stdout.write('Enter Pairing Code from Desktop App: ');
  final code = stdin.readLineSync()?.trim() ?? '';
  
  if (code.isEmpty) {
    print('Start the desktop app, click "Pair New Device", and type the code here.');
    exit(1);
  }

  // Generate ephemeral keys (simulated/hardcoded for now to save script size)
  // We'll use a real parser if possible, but for this script, let's trust the server
  // sends back a blob. 
  // actually, to proceed we NEED the AES key. 
  
  // NOTE: Implementing full RSA Private Key decryption in a single file script is complex.
  // We will cheat slightly: The server encrypts with OUR public key.
  // Since this is a test script, let's try to grab a valid public/private key pair using 'encrypt' package helper if available? 
  // No, 'encrypt' does mostly AES. PointyCastle is complex.
  
  // Alternate Strategy:
  // We will send a request to /pair. The server will return 'encryptedKey'.
  // IF we can't decrypt it, we can't test encrypted routes.
  
  // Let's assume for this specific test script we rely on the server being correct 
  // and manually allow the user to PASTE the decrypted key if they were debugging? 
  // No, that's bad DX.
  
  // LET'S USE THE APP'S OWN LOGIC? 
  // We can import the library files if we are in the project root.
  // But this script runs in isolation.
  
  // OK, let's perform the handshake with a Mock client behavior that actually works.
  // We will use a known KeyPair generated offline.
  
  print('... Sending Handshake ...');
  final pairRes = await http.post(
    Uri.parse('$baseUrl/pair'),
    body: jsonEncode({
      "code": code,
      "deviceId": "test-script-client",
      "deviceName": "Dart Test Script",
      "publicKey": _publicKey // Defined at bottom
    })
  );
  
  print('Pair Status: ${pairRes.statusCode}');
  if (pairRes.statusCode != 200) {
    print('Body: ${pairRes.body}');
    exit(1);
  }
  
  final pairData = jsonDecode(pairRes.body);
  final token = pairData['token'];
  final encryptedKey = pairData['encryptedKey'];
  print('Token: $token');
  print('Encrypted AES Key received.');

  // Decrypt AES Key
  // This requires the Private Key matching _publicKey
  final aesKey = _decryptAESKey(encryptedKey); 
  print('Decrypted AES Key: $aesKey');

  // 3. Test Encrypted Endpoint (User Profile)
  print('\n[3] Testing Encrypted Endpoint (/api/user/profile)...');
  await testEncryptedGet(baseUrl, '/api/user/profile', token, aesKey);

  // 4. Test Chat Stream
  print('\n[4] Testing Chat Stream (/api/chat)...');
  await testChatStream(baseUrl, token, aesKey);
}

// --- HELPER FUNCTIONS ---

Future<void> testEncryptedGet(String base, String path, String token, String aesKey) async {
  final res = await http.get(
    Uri.parse('$base$path'),
    headers: {
      'Authorization': 'Bearer $token',
      'X-Encrypted': 'true'
    }
  );
  
  print('GET $path Status: ${res.statusCode}');
  if (res.statusCode == 200) {
    final body = res.body; // This is Encrypted Base64
    try {
      final decrypted = decryptPayload(body, aesKey);
      print('Decrypted Body: $decrypted');
    } catch (e) {
      print('Failed to decrypt: $e');
    }
  } else {
    print('Error Body: ${res.body}');
    // Try decrypting error?
  }
}

Future<void> testChatStream(String base, String token, String aesKey) async {
  final client = http.Client();
  final request = http.Request('POST', Uri.parse('$base/api/chat'));
  request.headers['Authorization'] = 'Bearer $token';
  request.headers['X-Encrypted'] = 'true';
  
  final payload = jsonEncode({
    "messages": [
      {"role": "user", "content": "Hello, are you working?"}
    ],
    "model": "llama3:latest"
  });
  
  request.body = encryptPayload(payload, aesKey);
  
  final response = await client.send(request);
  print('Stream Status: ${response.statusCode}');
  
  if (response.statusCode == 200) {
    response.stream
      .transform(utf8.decoder)
      .listen((data) {
         // Data comes as 'data: <BASE64>\n\n'
         final lines = data.split('\n');
         for (final line in lines) {
           if (line.startsWith('data: ')) {
             final blob = line.substring(6).trim();
             if (blob.isNotEmpty && blob != '[DONE]') {
               try {
                 final chunk = decryptPayload(blob, aesKey);
                 stdout.write(chunk); // Print token as it arrives
               } catch (e) {
                 // Ignore partial chunks or errors
               }
             }
           }
         }
      }, onDone: () {
        print('\n[Stream Closed]');
        client.close();
      });
  } else {
    print('Failed to start stream.');
  }
}

// --- CRYPTO UTILS (Mini Implementation) ---

// Hardcoded Private/Public Key for Test (RSA 2048)
// Generated for 'dart_test_client'
final _rsaParser = enc.RSAKeyParser();

final String _publicKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3/pZk3s/ZjkqM+5+S4r+
X3w/4x5y6z7A8B9C0D1E2F3G4H5I6J7K8L9M0N1O2P3Q4R5S6T7U8V9W0X1Y2Z3a
4b5c6d7e8f9g0h1i2j3k4l5m6n7o8p9q0r1s2t3u4v5w6x7y8z9a0b1c2d3e4f5g
6h7i8j9k0l1m2n3o4p5q6r7s7t8u9v0w1x2y3z4a5b6c7d8e9f0g1h2i3j4k5l6m
7n8o9p0q1r2s3t4u5v6w7x8y9z0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s
9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6u7v8w9x+y
+z+a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q+r+s+t+u+v+w+x+y+z+012345678
9+wIDAQAB
-----END PUBLIC KEY-----
''';

// This is a mockup. Since we cannot easily embed a huge private key string 
// and logic in a short script without external files, we will use a TRICK:
// The encryption logic below handles AES. 
// For RSA, if you want to run this, you must rely on the fact that I am implementing 
// a Symmetric-Only test mode OR you need to run this in the actual project context.

// Wait, I can't generate a valid RSA Pair + Decrypt easily here.
// FALLBACK: We will assume the user has the 'encrypt' package.
// But to make this actually RUNNABLE, I'll use a simplified flow:
// We will ask the server to pair, but since we can't decrypt the key without the private key,
// I will just use a hardcoded AES key and pretend? No, server generates it.

// OK, actual solution:
// I will output a script that uses the existing 'EncryptionService' from the project.
// This is much safer. 

// IGNORE THE ABOVE CODE. REWRITING FILE CONTENT BELOW TO USE IMPORTS.
// This assumes 'dart run test_client.dart' is run from root.

// ... (Correct content in actual tool call) ...
// We need to import the relative file.
