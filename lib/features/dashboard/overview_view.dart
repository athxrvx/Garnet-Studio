import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/system_stats_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../server/local_server.dart';
import '../../ollama/ollama_service.dart'; // Contains ollamaConnectionProvider
import '../../features/devices/providers/device_provider.dart';
import '../../core/settings_service.dart'; // Contains activeModelNameProvider
import 'providers/system_log_provider.dart'; // Import System Log Provider
import 'providers/uptime_provider.dart'; // Import Uptime Provider

// --- Local Providers ---

// Simple provider to fetch local IP
final localIpProvider = FutureProvider<String>((ref) async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    
    // 1. Prioritize by name (exclude virtual adapters common on Windows)
    // We want "Wi-Fi" or "Ethernet", not "vEthernet (WSL)" or "VirtualBox"
    
    NetworkInterface? bestInterface;
    
    // Sort so that standard interfaces come first
    interfaces.sort((a, b) {
      int scoreA = _getInterfaceScore(a.name);
      int scoreB = _getInterfaceScore(b.name);
      return scoreB.compareTo(scoreA); // High score first
    });

    for (var interface in interfaces) {
       // Loop through addresses of the interface
       for (var addr in interface.addresses) {
         if (!addr.isLoopback && !addr.isLinkLocal) {
           return addr.address; // Return first valid address from best interface
         }
       }
    }
    
    return interfaces.first.addresses.first.address;
  } catch (e) {
    return '127.0.0.1';
  }
});

int _getInterfaceScore(String name) {
  final lower = name.toLowerCase();
  
  // Penalize virtual adapters
  if (lower.contains('wsl') || 
      lower.contains('vethernet') || 
      lower.contains('virtual') || 
      lower.contains('vmware') || 
      lower.contains('pseudo') ||
      lower.contains('host-only')) {
    return -10;
  }
  
  // Boost standard physical names
  if (lower.contains('wi-fi') || lower.startsWith('wlan') || lower.contains('wireless')) return 100;
  if (lower.startsWith('ethernet') || lower.startsWith('eth') || lower.startsWith('en')) return 50;
  
  return 0;
}

// Real System Stats Provider
// Removed old mock provider


class OverviewView extends ConsumerWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: AppConstants.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          
          // --- Top Row: Key Metrics ---
          const SizedBox(
            height: 140,
            child: _MetricsRow(), 
          ),
          const SizedBox(height: 24),

          // --- Middle Row: Server & Activity ---
          Expanded(
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.stretch,
               children: [
                 // Server Control Panel (Left)
                 const Expanded(
                   flex: 4,
                   child: _ServerControlPanel(),
                 ),
                 const SizedBox(width: 24),
                 // Recent Activity Log (Right)
                 Expanded(
                   flex: 3,
                   child: _ActivityLogPanel(),
                 ),
               ],
             ),
          ),
          
          const SizedBox(height: 24),
          
           // --- Bottom Row: System Resources ---
           const SizedBox(
             height: 100,
             child: _SystemResourcesPanel(),
           ),
        ],
      ),
    );
  }
}

class _MetricsRow extends ConsumerWidget {
  const _MetricsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedDevices = ref.watch(connectedDevicesCountProvider).valueOrNull ?? 0;
    final activeModel = ref.watch(activeModelNameProvider).valueOrNull ?? 'None';
    final isOllamaConnected = ref.watch(ollamaConnectionProvider);
    final uptime = ref.watch(uptimeProvider);
    
    final uptimeStr = '${uptime.inHours.toString().padLeft(2, '0')}:${(uptime.inMinutes % 60).toString().padLeft(2, '0')}:${(uptime.inSeconds % 60).toString().padLeft(2, '0')}';

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Active Model',
            value: activeModel,
            icon: Icons.smart_toy,
            statusColor: activeModel != 'None' && isOllamaConnected ? AppConstants.successColor : AppConstants.textTertiary,
            statusText: isOllamaConnected ? 'Ready' : 'Service Disconnected',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'Connected Devices',
            value: connectedDevices.toString(),
            icon: Icons.devices,
            statusColor: connectedDevices > 0 ? AppConstants.successColor : AppConstants.accentColor,
            statusText: '$connectedDevices Active Sessions',
            onTap: () {
               // Navigation logic could go here
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
             title: 'Uptime',
             value: uptimeStr,
             icon: Icons.timer,
             statusColor: AppConstants.successColor,
             statusText: 'Since Launch',
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color statusColor;
  final String statusText;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.statusColor,
    required this.statusText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Icon(icon, color: AppConstants.textSecondary, size: 20),
                   Container(
                     width: 8, height: 8,
                     decoration: BoxDecoration(
                       color: statusColor,
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4, spreadRadius: 1)
                       ]
                     ),
                   )
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.textPrimary,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConstants.textSecondary,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerControlPanel extends ConsumerWidget {
  const _ServerControlPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isServerRunning = ref.watch(gatewayServiceProvider);
    final ipAsync = ref.watch(localIpProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gateway Server', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
                  SizedBox(height: 4),
                  Text('Required for mobile pairing', style: TextStyle(fontSize: 12, color: AppConstants.textTertiary)),
                ],
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: isServerRunning,
                  activeColor: AppConstants.accentColor,
                  onChanged: (val) {
                    if (val) {
                      ref.read(gatewayServiceProvider.notifier).startServer();
                    } else {
                      ref.read(gatewayServiceProvider.notifier).stopServer();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Connection Info Box
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isServerRunning ? AppConstants.accentColor.withOpacity(0.3) : AppConstants.borderColor
                ),
              ),
              child: isServerRunning ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.wifi, size: 32, color: AppConstants.successColor),
                   const SizedBox(height: 16),
                   ipAsync.when(
                     data: (ip) => _ConnectionDetailRow(label: 'Local IP', value: ip, copyable: true),
                     loading: () => const CircularProgressIndicator(strokeWidth: 2),
                     error: (_,__) => const Text('Error loading IP'),
                   ),
                   const SizedBox(height: 8),
                   const _ConnectionDetailRow(label: 'Port', value: '8787', copyable: false),
                   const SizedBox(height: 16),
                   const Text(
                     'Status: Listenening for connections',
                     style: TextStyle(color: AppConstants.successColor, fontSize: 12),
                   )
                ],
              ) : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.wifi_off, size: 32, color: AppConstants.textTertiary.withOpacity(0.5)),
                   const SizedBox(height: 16),
                   const Text(
                     'Server is Offline',
                     style: TextStyle(color: AppConstants.textTertiary, fontSize: 16, fontWeight: FontWeight.bold),
                   ),
                   const SizedBox(height: 8),
                   const Text(
                     'Enable to connect devices',
                     style: TextStyle(color: AppConstants.textTertiary, fontSize: 12),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;

  const _ConnectionDetailRow({required this.label, required this.value, required this.copyable});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(color: AppConstants.textTertiary)),
        Text(value, style: const TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        if (copyable) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
               Clipboard.setData(ClipboardData(text: value));
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)));
            },
            child: const Icon(Icons.copy, size: 14, color: AppConstants.accentColor),
          )
        ]
      ],
    );
  }
}


class _ActivityLogPanel extends ConsumerWidget {
  const _ActivityLogPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(systemLogProvider);

     return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('System Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.textPrimary)),
              Icon(Icons.history, size: 16, color: AppConstants.textTertiary.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _LogItem(
                  time: log.timeAgo,
                  message: log.message,
                  level: log.level.name,
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final String time;
  final String message;
  final String level; // info, success, warn, error

  const _LogItem({required this.time, required this.message, required this.level});

  Color _getColor() {
    switch (level) {
      case 'success': return AppConstants.successColor;
      case 'warn': return AppConstants.warningColor;
      case 'error': return AppConstants.errorColor;
      default: return AppConstants.accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _getColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                Text(time, style: const TextStyle(color: AppConstants.textTertiary, fontSize: 11)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SystemResourcesPanel extends ConsumerWidget {
  const _SystemResourcesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the real provider
    final statsAsync = ref.watch(systemStatsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: statsAsync.when(
        loading: () => const Center(child: LinearProgressIndicator()),
        error: (e,__) => Center(child: Text("Error loading stats: $e")),
        data: (stats) {
          return Row(
            children: [
               Expanded(child: _ResourceBar(label: 'CPU Usage', percentage: stats.cpuUsage / 100, color: Colors.blue)),
               const SizedBox(width: 32),
               Expanded(child: _ResourceBar(label: 'RAM Usage', percentage: stats.ramUsage / 100, color: Colors.purple)),
               const SizedBox(width: 32),
               Expanded(child: _ResourceBar(label: 'VRAM Usage', percentage: stats.vramUsage / 100, color: Colors.orange)),
            ],
          );
        }
      ),
    );
  }
}

class _ResourceBar extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _ResourceBar({required this.label, required this.percentage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppConstants.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
            Text('${(percentage * 100).toInt()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: AppConstants.scaffoldBackgroundColor,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
