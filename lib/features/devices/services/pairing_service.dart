import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PairingService {
  String? _currentCode;
  DateTime? _codeGeneratedAt;
  
  // Generate a new 6-digit code
  String generatePairingCode() {
    final rng = Random();
    _currentCode = (rng.nextInt(900000) + 100000).toString();
    _codeGeneratedAt = DateTime.now();
    return _currentCode!;
  }
  
  // Verify the code
  bool verifyCode(String code) {
    if (_currentCode == null) return false;
    
    // Optional: Code expiry (e.g. 5 minutes)
    if (DateTime.now().difference(_codeGeneratedAt!).inMinutes > 5) {
      _currentCode = null;
      return false;
    }
    
    // Check equality
    // Once verified, we might want to invalidate it or keep it for a short grace period?
    // Usually invalidate immediately to prevent replay.
    final isValid = _currentCode == code;
    if (isValid) {
      _currentCode = null; // Consume the code
    }
    return isValid;
  }
  
  String? get currentCode => _currentCode;
}

final pairingServiceProvider = Provider<PairingService>((ref) {
  return PairingService();
});
