import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/local_server_service.dart';
import '../../services/mdns_service.dart';

final localServerServiceProvider = Provider<LocalServerService>((ref) {
  return LocalServerService();
});

final mdnsServiceProvider = Provider<MdnsService>((ref) {
  return MdnsService();
});

final pairingRequestStreamProvider = StreamProvider<PairingRequest>((ref) {
  final server = ref.watch(localServerServiceProvider);
  return server.pairingRequestStream;
});

// A provider to manage the initialization of services
final serverInitializationProvider = FutureProvider<void>((ref) async {
  final server = ref.read(localServerServiceProvider);
  final mdns = ref.read(mdnsServiceProvider);
  
  await server.start();
  await mdns.registerService();
  
  ref.onDispose(() {
    server.stop();
    mdns.unregisterService();
  });
});
