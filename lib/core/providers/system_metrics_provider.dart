import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final memoryUsageProvider = StreamProvider<double>((ref) async* {
  while (true) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // ProcessInfo.currentRss returns bytes. Convert to GB.
      yield ProcessInfo.currentRss / (1024 * 1024 * 1024);
    } else {
      yield 0.0;
    }
    await Future.delayed(const Duration(seconds: 2));
  }
});

final localIpProvider = FutureProvider<String>((ref) async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );

    // simple priority list: prefer interfaces that are NOT virtual/vpn
    for (var interface in interfaces) {
      // Check interface name for keywords that suggest virtual/container adapters
      final name = interface.name.toLowerCase();
      if (!name.contains('wsl') && 
          !name.contains('vethernet') && 
          !name.contains('docker') && 
          !name.contains('virtual') &&
          !name.contains('pseudo') &&
          !name.contains('vmware')) {
        
        // This looks like a physical interface, return its address
        if (interface.addresses.isNotEmpty) {
          return interface.addresses.first.address;
        }
      }
    }

    // Fallback: If no "clean" interface found, return the first interface that has an address
    for (var interface in interfaces) {
       if (interface.addresses.isNotEmpty) {
          return interface.addresses.first.address;
       }
    }

    return '127.0.0.1';
  } catch (e) {
    return 'Unknown';
  }
});
