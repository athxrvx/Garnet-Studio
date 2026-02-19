import 'package:nsd/nsd.dart';
import '../core/constants/app_constants.dart';

class MdnsService {
  Registration? _registration;

  Future<void> startDiscovery() async {
    // For client side (mobile), not studio. Studio broadcasts.
  }

  Future<void> registerService() async {
    try {
      _registration = await register(
        Service(
          name: AppConstants.serviceHostname,
          type: AppConstants.serviceType,
          port: AppConstants.defaultServerPort,
        ),
      );
      print('mDNS Service registered: ${_registration?.service.name}');
    } catch (e) {
      print('Error registering mDNS service: $e');
    }
  }

  Future<void> unregisterService() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }
}
