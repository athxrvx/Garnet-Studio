import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../server/local_server.dart';
import '../../ollama/ollama_service.dart';
import '../../core/providers/system_metrics_provider.dart';
import '../../features/devices/repositories/device_repository.dart';
import '../../features/devices/providers/device_provider.dart';
import '../../features/chat/ollama_provider.dart'; // Import ollamaConnectionProvider from here or update reference
import '../../core/settings_service.dart';
import '../../features/dashboard/providers/network_traffic_provider.dart';


class StatusPanel extends ConsumerWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    
    // Watch providers
    final isServerRunning = ref.watch(gatewayServiceProvider);
    final isOllamaConnected = ref.watch(ollamaConnectionProvider);
    final traffic = ref.watch(networkTrafficProvider);
    
    final activeModelAsync = ref.watch(activeModelNameProvider);
    final deviceCountAsync = ref.watch(connectedDevicesCountProvider);
    // Add memory/ip providers back
    final localIpAsync = ref.watch(localIpProvider);
    // Note: memoryUsageProvider might not exist in context, I saw it used but didn't verify import carefully. Assuming it existed.
    // Wait, the previous readFile output showed: final memoryAsync = ref.watch(memoryUsageProvider);
    // I need to ensure I don't break existing code. Let me check if memoryUsageProvider is imported.
    // It was imported from `../../core/providers/system_metrics_provider.dart`.
    // I'll keep existing provider watches.

    // Re-watch existing:
    final memoryAsync = ref.watch(memoryUsageProvider);


    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppConstants.sidebarBackgroundColor, 
        border: Border(left: BorderSide(color: AppConstants.borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   // ... (Existing System Status Header)
                   Text(
                    'SYSTEM STATUS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
            
                  // Server Status
                  _StatusRow(
                    label: 'HTTP Gateway',
                    value: isServerRunning ? 'RUNNING' : 'STOPPED',
                    statusColor: isServerRunning ? Colors.green : Colors.red,
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isServerRunning,
                        onChanged: (v) {
                           if (v) {
                             ref.read(gatewayServiceProvider.notifier).startServer();
                           } else {
                             ref.read(gatewayServiceProvider.notifier).stopServer();
                           }
                        },
                        activeColor: AppConstants.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Ollama Status
                  _StatusRow(
                    label: 'Ollama Core',
                    value: isOllamaConnected ? 'CONNECTED' : 'DISCONNECTED',
                    statusColor: isOllamaConnected ? AppConstants.successColor : AppConstants.errorColor,
                  ),
                  const SizedBox(height: 24),
            
                  // System Info
                   Text(
                    'METRICS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ... (Existing Metric Tiles)
                  _MetricTile(
                    icon: Icons.dns,
                    label: 'Local IP',
                    value: localIpAsync.valueOrNull ?? 'Scanning...',
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.storage, size: 16, color: AppConstants.textTertiary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Memory Usage', style: TextStyle(color: AppConstants.textTertiary, fontSize: 11)),
                            Text('${(memoryAsync.valueOrNull ?? 0).toStringAsFixed(1)} GB', style: const TextStyle(fontSize: 13, color: AppConstants.textPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.smartphone, size: 16, color: AppConstants.textTertiary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Active Devices', style: TextStyle(color: AppConstants.textTertiary, fontSize: 11)),
                            Text('${deviceCountAsync.valueOrNull ?? 0}', style: const TextStyle(fontSize: 13, color: AppConstants.textPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                   Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.smart_toy, size: 16, color: AppConstants.textTertiary),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Active Model', style: TextStyle(color: AppConstants.textTertiary, fontSize: 11)),
                            Text(activeModelAsync.valueOrNull ?? 'Loading...', style: const TextStyle(fontSize: 13, color: AppConstants.textPrimary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Network Traffic Graph (Functional Mock)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Network Traffic', style: TextStyle(color: AppConstants.textTertiary, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppConstants.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConstants.borderColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: _NetworkGraphPainter(
                      data: traffic, 
                      color: AppConstants.accentColor,
                      fillColor: AppConstants.accentColor.withOpacity(0.1)
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkGraphPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color fillColor;

  _NetworkGraphPainter({required this.data, required this.color, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final widthStep = size.width / (data.length - 1);
    
    path.moveTo(0, size.height * (1 - data[0]));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * (1 - data[0]));

    for (int i = 1; i < data.length; i++) {
      final x = i * widthStep;
      final y = size.height * (1 - data[i]);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }
    
    fillPath.lineTo(size.width, size.height); // Close fill loop
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NetworkGraphPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}


class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color statusColor;
  final Widget? trailing;

  const _StatusRow({
    required this.label,
    required this.value,
    this.statusColor = AppConstants.textPrimary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppConstants.textPrimary)),
              ],
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  
  const _MetricTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppConstants.textTertiary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppConstants.textTertiary, fontSize: 11)),
              Text(value, style: TextStyle(fontSize: 13, color: AppConstants.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}
