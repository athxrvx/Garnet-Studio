enum DeviceStatus {
  discovered, // Found via mDNS but not verified/paired
  verified,   // Handshake success
  paired,     // Paired and in DB
  connected,  // Paired and Online
  offline     // Paired but not seen
}

class Device {
  final String id;
  final String name;
  final String version;
  final String ipAddress;
  final int port;
  final DateTime lastActive;
  final DeviceStatus status;
  final String? encryptionKey; // Added for E2EE

  Device({
    required this.id,
    required this.name,
    required this.version,
    required this.ipAddress,
    this.port = 8080,
    required this.lastActive,
    this.status = DeviceStatus.discovered,
    this.encryptionKey,
  });

  Device copyWith({
    String? id,
    String? name,
    String? version,
    String? ipAddress,
    int? port,
    DateTime? lastActive,
    DeviceStatus? status,
    String? encryptionKey,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      lastActive: lastActive ?? this.lastActive,
      status: status ?? this.status,
      encryptionKey: encryptionKey ?? this.encryptionKey,
    );
  }

  factory Device.fromDb(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      name: map['device_name'],
      version: 'Unknown',
      ipAddress: '',
      lastActive: DateTime.parse(map['last_active']),
      status: DeviceStatus.offline,
      encryptionKey: map['encryption_key'], // Load key
    );
  }
}
