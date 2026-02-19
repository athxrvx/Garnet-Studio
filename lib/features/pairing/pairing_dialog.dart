import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/local_server_service.dart';
import '../../core/constants/app_constants.dart';
import '../server/server_provider.dart';

class PairingDialog extends ConsumerWidget {
  final PairingRequest request;

  const PairingDialog({super.key, required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: AppConstants.sidebarBackground,
      title: Row(
        children: [
          Icon(Icons.phonelink_ring, color: AppConstants.accentColor),
          const SizedBox(width: 8),
          const Text('New Pairing Request', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Device', request.deviceName),
          _buildInfoRow('IP Address', request.ip),
          const SizedBox(height: 16),
          const Text(
            'Pairing Code:',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppConstants.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppConstants.accentColor.withOpacity(0.5)),
            ),
            child: Text(
              request.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter this code on your mobile device to connect.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(localServerServiceProvider).rejectPairing(request.code);
            Navigator.of(context).pop();
          },
          child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppConstants.accentColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            ref.read(localServerServiceProvider).approvePairing(request.code);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pairing Approved. Waiting for device...')),
            );
          },
          child: const Text('Approve'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
