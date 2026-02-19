// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatSession _$ChatSessionFromJson(Map<String, dynamic> json) => ChatSession(
  id: json['id'] as String,
  title: json['title'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  messages:
      (json['messages'] as List<dynamic>?)
          ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$ChatSessionToJson(ChatSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'messages': instance.messages,
    };
