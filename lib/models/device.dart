import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

@JsonSerializable()
class Device {
  final String id;
  final String name;
  final String ip;
  final String tokenHash;
  final DateTime lastUsed;
  final DateTime dateAdded;

  Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.tokenHash,
    required this.lastUsed,
    required this.dateAdded,
  });

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  Device copyWith({
    String? name,
    String? ip,
    String? tokenHash,
    DateTime? lastUsed,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      tokenHash: tokenHash ?? this.tokenHash,
      lastUsed: lastUsed ?? this.lastUsed,
      dateAdded: dateAdded,
    );
  }
}
