import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../core/settings_service.dart';
import '../../server/local_server.dart';
import '../../services/ollama_service.dart';
import '../../services/chat_history_service.dart';
import '../../features/dashboard/providers/system_log_provider.dart'; // Import Log Provider

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  // Loading State
  bool _isLoading = true;

  // Settings State
  bool _autoStartServer = true;
  String _activeModel = 'llama3:latest';
  List<String> _availableModels = ['llama3:latest']; // Default placeholder
  String _ipAddress = 'Calculating...';

  // Controllers
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _systemPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _loadSettings(),
      _fetchModels(),
      _fetchIpAddress(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSettings() async {
    final settings = ref.read(settingsServiceProvider);
    
    final autoStart = await settings.getSetting('gateway_server_autostart');
    final activeModel = await settings.getSetting('active_model');
    final userName = await settings.getSetting('user_name');
    final systemPrompt = await settings.getSetting('system_prompt');

    if (mounted) {
      setState(() {
        _autoStartServer = autoStart == null || autoStart == 'true';
        if (activeModel != null) _activeModel = activeModel;
        _userNameController.text = userName ?? 'User';
        _systemPromptController.text = systemPrompt ?? 
            "You are Garnet, a helpful and friendly AI assistant. Be concise.";
      });
    }
  }

  Future<void> _fetchModels() async {
    final ollamaService = ref.read(ollamaServiceProvider);
    final models = await ollamaService.listModels();
    if (mounted && models.isNotEmpty) {
      setState(() {
        _availableModels = models;
        if (!_availableModels.contains(_activeModel)) {
           _activeModel = _availableModels.first;
           _saveSetting('active_model', _activeModel);
        }
      });
    }
  }

  Future<void> _fetchIpAddress() async {
    try {
      final info = NetworkInfo();
      String? wifiIp = await info.getWifiIP();
      
      if (wifiIp == null) {
        // Fallback to searching interfaces
        for (var interface in await NetworkInterface.list()) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              wifiIp = addr.address;
              break;
            }
          }
          if (wifiIp != null) break;
        }
      }
      
      if (mounted) {
         setState(() => _ipAddress = wifiIp ?? 'Unknown');
      }
    } catch (e) {
      if (mounted) setState(() => _ipAddress = 'Unknown');
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setSetting(key, value);
    // Force refresh providers if any watch
    if (key == 'active_model') {
       ref.invalidate(activeModelNameProvider);
       ref.read(systemLogProvider.notifier).addLog('Active model changed to "$value"', level: LogLevel.info);
    } else if (key == 'user_name') {
       ref.invalidate(userNameProvider);
    }
  }

  Future<void> _toggleAutoStart(bool value) async {
    setState(() => _autoStartServer = value);
    await _saveSetting('gateway_server_autostart', value.toString());
  }

  Future<void> _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text("This action cannot be undone. All chat sessions will be deleted."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Clear", style: TextStyle(color: AppConstants.errorColor))
          ),
        ],
      )
    );

    if (confirm == true) {
       await ref.read(chatHistoryServiceProvider).clearHistory();
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat history cleared")));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Inherited from layout
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppConstants.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            
            // --- AI Configuration ---
            _buildSectionHeader('AI Configuration'),
            _buildDropdownTile(
              title: 'Default Model',
              subtitle: 'Select the Ollama model to use for chats.',
              value: _activeModel,
              items: _availableModels,
              onChanged: (val) {
                if (val != null) {
                  setState(() => _activeModel = val);
                  _saveSetting('active_model', val);
                }
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _systemPromptController,
              label: 'System Prompt',
              hint: 'Define Garnet\'s personality...',
              maxLines: 3,
              onChanged: (val) => _saveSetting('system_prompt', val),
            ),
            const SizedBox(height: 16),
            _buildActionTile(
              title: 'Clear Chat History',
              subtitle: 'Remove all saved conversations locally.',
              icon: Icons.delete_outline,
              color: AppConstants.errorColor,
              onTap: _clearChatHistory,
            ),
            
            const SizedBox(height: 32),

            // --- User Profile ---
            _buildSectionHeader('Profile'),
            _buildTextField(
              controller: _userNameController,
              label: 'Your Name',
              hint: 'What should Garnet call you?',
              maxLines: 1,
              onChanged: (val) => _saveSetting('user_name', val),
            ),
            
            const SizedBox(height: 32),

            // --- Connectivity ---
            _buildSectionHeader('Connectivity'),
            SwitchListTile(
              title: const Text('Auto-Start Gateway Server'),
              subtitle: const Text('Start local server on app launch.'),
              value: _autoStartServer,
              onChanged: (bool value) => _toggleAutoStart(value),
              activeColor: AppConstants.accentColor,
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, _) {
                final isServerRunning = ref.watch(gatewayServiceProvider);
                // final port = ref.read(gatewayServiceProvider.notifier).port; // Use watch if we want reactive updates on port change, but port is const usually.
                // Re-reading notifier to access port is fine.
                final port = ref.read(gatewayServiceProvider.notifier).port;
                
                return InkWell(
                  onTap: () async {
                     final notifier = ref.read(gatewayServiceProvider.notifier);
                     if (isServerRunning) {
                       await notifier.stopServer();
                     } else {
                       await notifier.startServer();
                     }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isServerRunning ? AppConstants.errorColor.withOpacity(0.1) : AppConstants.successColor.withOpacity(0.1),
                      border: Border.all(color: isServerRunning ? AppConstants.errorColor : AppConstants.successColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(isServerRunning ? Icons.stop_circle_outlined : Icons.play_circle_outlined, 
                             color: isServerRunning ? AppConstants.errorColor : AppConstants.successColor, size: 32),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isServerRunning ? 'Stop Local Server' : 'Start Local Server', 
                                 style: TextStyle(color: isServerRunning ? AppConstants.errorColor : AppConstants.successColor, fontWeight: FontWeight.bold)),
                            Text(isServerRunning ? 'Running on http://$_ipAddress:$port' : 'Server is currently stopped.',
                                 style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
            ),
            
            const SizedBox(height: 32),
            
            // --- Developer ---
            _buildSectionHeader('Developer'),
            ListTile(
               title: const Text('Reset Onboarding', style: TextStyle(color: Colors.orange)),
               subtitle: const Text('Clear setup and show welcome screen next launch.'),
               leading: const Icon(Icons.restart_alt, color: Colors.orange),
               onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset Onboarding?'),
                      content: const Text('This will clear your profile settings and force the onboarding screen to appear again.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset', style: TextStyle(color: Colors.orange))),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    await ref.read(settingsServiceProvider).setSetting('onboarding_complete', 'false');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding reset. Restart the app.')));
                    }
                  }
               },
            ),
            
            const SizedBox(height: 48),
            Center(
              child: Text(
                '${AppConstants.appName} v${AppConstants.appVersion}',
                style: const TextStyle(color: AppConstants.textTertiary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppConstants.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title, 
    required String subtitle, 
    required bool value, 
    required Function(bool) onChanged
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppConstants.textPrimary, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeColor: AppConstants.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title, 
    required String subtitle, 
    required IconData icon,
    required Color color,
    required VoidCallback onTap
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppConstants.textPrimary, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppConstants.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppConstants.surfaceColorAlt,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppConstants.borderColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(value) ? value : null,
                dropdownColor: AppConstants.surfaceColorAlt,
                style: const TextStyle(color: AppConstants.textPrimary),
                icon: const Icon(Icons.arrow_drop_down, color: AppConstants.textSecondary),
                items: items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppConstants.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: AppConstants.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppConstants.textTertiary),
            filled: true,
            fillColor: AppConstants.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: onChanged, // Saves on every keystroke (debouncing recommended for heavy apps)
        ),
      ],
    );
  }
}