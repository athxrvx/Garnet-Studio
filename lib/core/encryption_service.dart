import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart'; // For RSA Key parsing if needed

class EncryptionService {
  // Generate a random 32-byte (256-bit) AES Key
  static String generateAESKey() {
    final key = Key.fromSecureRandom(32);
    return base64.encode(key.bytes);
  }

  // Encrypt the AES Key with the Client's RSA Public Key
  // This allows the client to securely receive the session key
  static String encryptAESKeyWithRSA(String aesKeyBase64, String publicKeyPEM) {
    final parser = RSAKeyParser();
    final publicKey = parser.parse(publicKeyPEM) as RSAPublicKey;
    final encrypter = Encrypter(RSA(publicKey: publicKey));
    
    final encrypted = encrypter.encrypt(aesKeyBase64);
    return encrypted.base64;
  }

  // Encrypt data using AES-GCM (Preferred for E2EE)
  // We use the shared AES Key
  static String encryptPayload(String jsonPayload, String aesKeyBase64) {
    if (aesKeyBase64.isEmpty) return jsonPayload;
    
    final key = Key.fromBase64(aesKeyBase64);
    // GCM requires nonce/IV. standard is 12 bytes
    final iv = IV.fromSecureRandom(12); 
    
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(jsonPayload, iv: iv);
    
    // Return format: Base64([IV (12 bytes)] + [Ciphertext + AuthTag])
    final combined = iv.bytes + encrypted.bytes;
    return base64.encode(combined);
  }

  // Decrypt data using AES-GCM
  static String decryptPayload(String encryptedPayload, String aesKeyBase64) {
    if (encryptedPayload.isEmpty) return '';
    
    final key = Key.fromBase64(aesKeyBase64);
    final combined = base64.decode(encryptedPayload);
    
    // Extract IV (first 12 bytes)
    if (combined.length < 12) throw FormatException('Invalid payload size');
    final ivBytes = combined.sublist(0, 12);
    final iv = IV(ivBytes);
    
    // Extract Ciphertext + Tag
    final ciphertextBytes = combined.sublist(12);
    final encrypted = Encrypted(ciphertextBytes);
    
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    
    return encrypter.decrypt(encrypted, iv: iv);
  }
}
