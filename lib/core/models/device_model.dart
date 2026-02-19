import 'package:uuid/uuid.dart';

enum DeviceType {
  mobile,
  server,
  edgeAi, // 'Edge AI'
  tablet,
  desktop,
  other
}

enum DeviceStatus {
  online,
  offline,
  syncing,
  error
}

class DeviceModel {
  final String id;
  final String name;
  final DeviceType type;
  final DeviceStatus status;
  final String ipAddress;
  final int port;
  final double batteryLevel; // 0.0 to 1.0, -1 for unknown
  final DateTime lastSeen;

  DeviceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.ipAddress,
    required this.port,
    required this.batteryLevel,
    required this.lastSeen,
  });

  factory DeviceModel.create({
    required String name,
    required DeviceType type,
    required String ipAddress,
    int? port,
  }) {
    return DeviceModel(
      id: const Uuid().v4(),
      name: name,
      type: type,
      status: DeviceStatus.offline, // Default to offline until checked
      ipAddress: ipAddress,
      port: port ?? 80,
      batteryLevel: -1.0, 
      lastSeen: DateTime.now(),
    );
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DeviceType.values.firstWhere(
        (e) => e.toString() == json['type'], 
        orElse: () => DeviceType.other
      ),
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString() == json['status'], 
        orElse: () => DeviceStatus.offline
      ),
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int? ?? 80,
      batteryLevel: (json['batteryLevel'] as num?)?.toDouble() ?? -1.0,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'status': status.toString(),
      'ipAddress': ipAddress,
      'port': port,
      'batteryLevel': batteryLevel,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  DeviceModel copyWith({
    String? name,
    DeviceType? type,
    DeviceStatus? status,
    String? ipAddress,
    int? port,
    double? batteryLevel,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case DeviceType.edgeAi: return 'Edge AI';
      case DeviceType.mobile: return 'Mobile';
      case DeviceType.server: return 'Server';
      case DeviceType.tablet: return 'Tablet';
      case DeviceType.desktop: return 'Desktop';
      default: return 'Device';
    }
  }
}

