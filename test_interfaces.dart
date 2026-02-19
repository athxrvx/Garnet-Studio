import 'dart:io';

void main() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false, 
    type: InternetAddressType.IPv4
  );
  for (var interface in interfaces) {
    print('Name: ${interface.name}');
    for (var addr in interface.addresses) {
      print('  IP: ${addr.address}');
    }
  }
}
