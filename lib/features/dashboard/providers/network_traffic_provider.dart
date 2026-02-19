import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkTrafficNotifier extends StateNotifier<List<double>> {
  Timer? _timer;
  final int _maxPoints = 60; // 60 data points

  NetworkTrafficNotifier() : super(List.filled(60, 0.0, growable: true)) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchTraffic());
  }

  Future<void> _fetchTraffic() async {
    double usage = 0.0;
    try {
      if (Platform.isWindows) {
        final result = await Process.run('typeperf', [
           r'\Network Interface(*)\Bytes Total/sec',
           '-sc', '1'
        ]);
        
        if (result.exitCode == 0) {
           final lines = result.stdout.toString().split('\n');
           // Find the data line (usually the one starting with a timestamp in quotes)
           // Or just the last non-empty line
           String? valueLine;
           for (final line in lines) {
             if (line.trim().isNotEmpty && line.contains('","') && !line.startsWith('"(PDH-CSV')) {
               valueLine = line;
             }
           }

           if (valueLine != null) {
              final parts = valueLine.split('","'); // Split by ","
              // Timestamp is parts[0] (or part of it)
              
              double totalBytes = 0.0;
              for (int i = 1; i < parts.length; i++) {
                 // Clean up the string (remove quotes, newlines)
                 String valStr = parts[i].replaceAll('"', '').trim();
                 double val = double.tryParse(valStr) ?? 0.0;
                 totalBytes += val;
              }
              
              // Normalize to a 0.0-1.0 scale (10MB/s = 1.0)
              usage = (totalBytes / (10 * 1024 * 1024)).clamp(0.0, 1.0);
           }
        }
      } else {
         usage = 0.05; // Fallback
      }
    } catch (e) {
      usage = 0.0;
    }

    if (mounted) {
      final currentList = List<double>.from(state);
      if (currentList.isNotEmpty) {
        currentList.removeAt(0);
      }
      currentList.add(usage);
      // Ensure we keep exactly 60
      while (currentList.length > _maxPoints) {
        currentList.removeAt(0);
      }
      state = currentList;
    }
  }
  
  void reportActivity() {}

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final networkTrafficProvider = StateNotifierProvider<NetworkTrafficNotifier, List<double>>((ref) {
  return NetworkTrafficNotifier();
});
