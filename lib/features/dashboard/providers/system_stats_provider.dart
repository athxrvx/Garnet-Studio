import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemStats {
  final double cpuUsage;
  final double ramUsage;
  final double vramUsage;

  const SystemStats({
    this.cpuUsage = 0.0,
    this.ramUsage = 0.0,
    this.vramUsage = 0.0,
  });
}

class SystemStatsNotifier extends StateNotifier<AsyncValue<SystemStats>> {
  Timer? _timer;

  SystemStatsNotifier() : super(const AsyncValue.loading()) {
    _startMonitoring();
  }

  void _startMonitoring() {
    _fetchStats();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchStats());
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    try {
      if (Platform.isWindows) {
        await _fetchWindowsStats();
      } else {
        // Fallback for other platforms
        if (mounted) {
           state = const AsyncValue.data(SystemStats(cpuUsage: 0, ramUsage: 0, vramUsage: 0));
        }
      }
    } catch (e, stack) {
      if (mounted) {
        // Log error but keep existing state if possible, or reset
        // System log provider would be nice here, but keeping it simple
      }
    }
  }

  Future<void> _fetchWindowsStats() async {
    try {
      // 1. CPU Load
      final cpuFuture = Process.run('powershell', [
        '-Command',
        r'Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average'
      ]);

      // 2. RAM
      final ramFuture = Process.run('powershell', [
        '-Command',
        r'Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json -Compress'
      ]);
      
      // 3. VRAM (NVIDIA)
      final vramFuture = Process.run('nvidia-smi', [
        '--query-gpu=utilization.memory',
        '--format=csv,noheader,nounits'
      ]);

      final results = await Future.wait([cpuFuture, ramFuture, vramFuture]);

      // Parse CPU
      double cpu = 0.0;
      if (results[0].exitCode == 0) {
         final cpuOut = results[0].stdout.toString().trim();
         if (cpuOut.isNotEmpty) {
           cpu = double.tryParse(cpuOut) ?? 0.0;
         }
      }

      // Parse RAM
      double ramUsage = 0.0;
      if (results[1].exitCode == 0) {
        final ramOut = results[1].stdout.toString().trim();
        // Regex for JSON keys
        final totalMatch = RegExp(r'"TotalVisibleMemorySize":\s*(\d+)').firstMatch(ramOut);
        final freeMatch = RegExp(r'"FreePhysicalMemory":\s*(\d+)').firstMatch(ramOut);

        if (totalMatch != null && freeMatch != null) {
          final total = double.parse(totalMatch.group(1)!);
          final free = double.parse(freeMatch.group(1)!);
          if (total > 0) {
            ramUsage = ((total - free) / total) * 100;
          }
        }
      }

      // Parse VRAM
      double vramUsage = 0.0;
      if (results[2].exitCode == 0) {
        final vramOut = results[2].stdout.toString().trim();
        final lines = vramOut.split('\n');
        if (lines.isNotEmpty && lines.first.isNotEmpty) {
          vramUsage = double.tryParse(lines.first.trim()) ?? 0.0;
        }
      }

      if (mounted) {
        state = AsyncValue.data(SystemStats(
          cpuUsage: cpu,
          ramUsage: ramUsage,
          vramUsage: vramUsage, 
        ));
      }

    } catch (e) {
      if (mounted) {
         state = const AsyncValue.data(SystemStats());
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final systemStatsProvider = StateNotifierProvider<SystemStatsNotifier, AsyncValue<SystemStats>>((ref) {
  return SystemStatsNotifier();
});
