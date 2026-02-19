import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garnet_studio/core/constants/app_constants.dart';
import 'models/device_model.dart';
import 'providers/device_provider.dart';

class DevicesView extends ConsumerWidget {
  const DevicesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch status for rebuilds
    final state = ref.watch(deviceManagerProvider);
    final notifier = ref.read(deviceManagerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppConstants.scaffoldBackgroundColor.withOpacity(0.9),
              AppConstants.sidebarBackgroundColor.withOpacity(0.9),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stylish Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.hub, size: 32, color: AppConstants.accentColor),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device Manager',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: AppConstants.textPrimary,
                            fontFamily: 'Segoe UI Variable Display',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage your secure device ecosystem',
                          style: TextStyle(color: AppConstants.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  _PairButton(
                    onPressed: () => _showPairingDialog(context, notifier),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Discovery Section with horizontal scroll
              if (state.discoveredDevices.isNotEmpty) ...[
                 Row(
                   children: [
                      const Icon(Icons.radar, size: 18, color: AppConstants.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                       "Nearby Devices",
                       style: TextStyle(fontWeight: FontWeight.w600, color: AppConstants.textSecondary, letterSpacing: 1),
                     ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 SizedBox(
                   height: 80,
                   child: ListView.separated(
                     scrollDirection: Axis.horizontal,
                     itemCount: state.discoveredDevices.length,
                     separatorBuilder: (c, i) => const SizedBox(width: 16),
                     itemBuilder: (context, index) {
                       final device = state.discoveredDevices[index];
                       return _DiscoveryChip(device: device);
                     },
                   ),
                 ),
                 const SizedBox(height: 40),
              ],

              // Authorized Devices Section
              Row(
                children: [
                   const Icon(Icons.verified_user_outlined, size: 18, color: AppConstants.textTertiary),
                   const SizedBox(width: 8),
                   const Text(
                    "Authorized Devices",
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.w600, 
                      color: AppConstants.textSecondary,
                      letterSpacing: 1
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: _buildAuthorizedSection(state, notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorizedSection(DeviceManagerState state, DeviceManagerNotifier notifier) {
    if (state.authorizedDevices.isEmpty) {
      return Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppConstants.surfaceColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppConstants.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppConstants.surfaceColorAlt
                ),
                child: Icon(Icons.phonelink_off, size: 48, color: AppConstants.textTertiary),
              ),
              const SizedBox(height: 24),
              const Text(
                "No devices connected",
                style: TextStyle(color: AppConstants.textSecondary, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                "Pair your mobile app to control Garnet Studio remotely.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppConstants.textTertiary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }


    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 140,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: state.authorizedDevices.length,
      itemBuilder: (context, index) {
        final device = state.authorizedDevices[index];
        return _AuthorizedCard(
          device: device, 
          onRevoke: () => notifier.revokeDevice(device.id)
        );
      },
    );
  }

  void _showPairingDialog(BuildContext context, DeviceManagerNotifier notifier) {
    // Generate code
    final code = notifier.initiatePairing();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return _PairingDialogContent(
          pairingCode: code,
          onClose: () {
             notifier.clearPairingCode();
             Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _PairButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _PairButton({required this.onPressed});

  @override
  State<_PairButton> createState() => _PairButtonState();
}

class _PairButtonState extends State<_PairButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? AppConstants.accentColor : AppConstants.accentColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: AppConstants.accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_link, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Pair New Device",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryChip extends StatelessWidget {
  final Device device;
  const _DiscoveryChip({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppConstants.borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppConstants.surfaceColorAlt,
            ),
             child: const Icon(Icons.phone_iphone, size: 16, color: AppConstants.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppConstants.textPrimary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  device.ipAddress,
                  style: const TextStyle(color: AppConstants.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorizedCard extends StatefulWidget {
  final Device device;
  final VoidCallback onRevoke;

  const _AuthorizedCard({required this.device, required this.onRevoke});

  @override
  State<_AuthorizedCard> createState() => _AuthorizedCardState();
}

class _AuthorizedCardState extends State<_AuthorizedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.device.status == DeviceStatus.connected;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isHovered ? AppConstants.surfaceColorAlt : AppConstants.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOnline 
                ? AppConstants.accentColor.withOpacity(_isHovered ? 0.6 : 0.3) 
                : AppConstants.borderColor,
             width: 1.5   
          ),
          boxShadow: [
             if (isOnline)
               BoxShadow(
                 color: AppConstants.accentColor.withOpacity(0.05),
                 blurRadius: 30,
                 spreadRadius: 0
               )
          ]
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOnline ? AppConstants.successColor.withOpacity(0.2) : AppConstants.surfaceColorAlt,
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off, 
                    size: 18, 
                    color: isOnline ? AppConstants.successColor : AppConstants.textTertiary
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.device.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: AppConstants.textPrimary,
                      fontSize: 16
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isHovered)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppConstants.textSecondary),
                    tooltip: 'Revoke Access',
                    onPressed: widget.onRevoke,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
              ],
            ),
            const Spacer(),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
               decoration: BoxDecoration(
                 color: isOnline ? AppConstants.successColor.withOpacity(0.1) : AppConstants.surfaceColorAlt,
                 borderRadius: BorderRadius.circular(50)
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(
                     width: 6, height: 6,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: isOnline ? AppConstants.successColor : AppConstants.textTertiary
                     ),
                   ),
                   const SizedBox(width: 8),
                   Text(
                      isOnline ? "Encrypted • Online" : "Offline",
                      style: TextStyle(
                        color: isOnline ? AppConstants.successColor.withOpacity(0.9) : AppConstants.textTertiary, 
                        fontSize: 11,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                 ],
               ),
             ),
             const SizedBox(height: 8),
            Text(
               widget.device.ipAddress.isNotEmpty ? widget.device.ipAddress : "No IP Address",
               style: const TextStyle(color: AppConstants.textTertiary, fontSize: 11, fontFamily: 'monospace')
            ),
          ],
        ),
      ),
    );
  }
}

class _PairingDialogContent extends StatefulWidget {
  final String pairingCode;
  final VoidCallback onClose;

  const _PairingDialogContent({
    required this.pairingCode,
    required this.onClose,
  });

  @override
  State<_PairingDialogContent> createState() => _PairingDialogContentState();
}

class _PairingDialogContentState extends State<_PairingDialogContent> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppConstants.surfaceColor,
      elevation: 20,
      shadowColor: AppConstants.accentColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: AppConstants.borderColor)),
      title: Column(
        children: [
          const Icon(Icons.phonelink_setup, size: 40, color: AppConstants.textSecondary),
          const SizedBox(height: 16),
          const Text('Pair New Device', style: TextStyle(color: AppConstants.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Open the Garnet Mobile app and enter this code",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppConstants.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConstants.accentColor.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.accentColor.withOpacity(0.1),
                    blurRadius: 30,
                    blurStyle: BlurStyle.inner
                  )
                ]
              ),
              child: Text(
                widget.pairingCode,
                style: const TextStyle(
                  fontSize: 56, 
                  fontWeight: FontWeight.bold, 
                  letterSpacing: 14, 
                  color: AppConstants.accentColor,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(color: AppConstants.accentColor, blurRadius: 10) // Text glow
                  ]
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 SizedBox(
                   width: 16, height: 16,
                   child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.textTertiary)
                 ),
                 SizedBox(width: 12),
                 Text(
                   "Waiting for connection...",
                   style: TextStyle(color: AppConstants.textTertiary, fontSize: 13),
                 ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: AppConstants.warningColor.withOpacity(0.08),
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: AppConstants.warningColor.withOpacity(0.2))
               ),
               child: const Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Icon(Icons.wifi, color: AppConstants.warningColor, size: 16),
                   SizedBox(width: 12),
                   Text("Devices must be on same network", style: TextStyle(color: AppConstants.warningColor, fontSize: 12)),
                 ],
               ),
             )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onClose,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: AppConstants.textSecondary
          ),
          child: const Text('Cancel'),
        ),
      ],
      actionsPadding: const EdgeInsets.only(bottom: 24),
      actionsAlignment: MainAxisAlignment.center,
    );
  }
}

