import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

enum MessageRole { user, assistant, system }

@JsonSerializable()
class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final bool isStreaming;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.isStreaming = false,
  });
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
  
  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
