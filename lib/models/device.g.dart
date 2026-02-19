// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
  id: json['id'] as String,
  name: json['name'] as String,
  ip: json['ip'] as String,
  tokenHash: json['tokenHash'] as String,
  lastUsed: DateTime.parse(json['lastUsed'] as String),
  dateAdded: DateTime.parse(json['dateAdded'] as String),
);

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'ip': instance.ip,
  'tokenHash': instance.tokenHash,
  'lastUsed': instance.lastUsed.toIso8601String(),
  'dateAdded': instance.dateAdded.toIso8601String(),
};
