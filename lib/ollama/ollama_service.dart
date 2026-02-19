import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/dashboard/providers/system_log_provider.dart';

class OllamaConnectionService extends StateNotifier<bool> {
  Timer? _healthCheckTimer;
  final String _baseUrl = 'http://localhost:11434';
  final SystemLogNotifier _systemLog;

  OllamaConnectionService(this._systemLog) : super(false) {
    _startHealthCheck();
  }

  void _startHealthCheck() {
    _checkHealth(); // Initial check
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkHealth());
  }

  Future<void> _checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/tags')); // Corrected URL
      if (response.statusCode == 200) {
        if (!state) {
          state = true;
          _systemLog.addLog('Ollama service connected', level: LogLevel.success);
        }
      } else {
        if (state) {
          state = false;
          _systemLog.addLog('Ollama service unreachable (HTTP ${response.statusCode})', level: LogLevel.error);
        }
      }
    } catch (e) {
      if (state) {
        state = false;
        _systemLog.addLog('Ollama service disconnected', level: LogLevel.error);
      }
    }
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}

final ollamaConnectionProvider = StateNotifierProvider<OllamaConnectionService, bool>((ref) {
  final systemLog = ref.read(systemLogProvider.notifier);
  return OllamaConnectionService(systemLog);
});
