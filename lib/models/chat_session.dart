import 'package:json_annotation/json_annotation.dart';
import 'chat_message.dart';

part 'chat_session.g.dart';

@JsonSerializable()
class ChatSession {
  final String id;
  final String title;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.messages = const [],
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) => _$ChatSessionFromJson(json);
  Map<String, dynamic> toJson() => _$ChatSessionToJson(this);

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}
