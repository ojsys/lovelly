// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String,
  senderId: json['sender_id'] as String,
  body: json['body'] as String,
  kind: json['kind'] as String,
  sentAt: DateTime.parse(json['sent_at'] as String),
  seenAt: json['seen_at'] == null ? null : DateTime.parse(json['seen_at'] as String),
  flagged: json['flagged'] as bool,
  flagReason: json['flag_reason'] as String,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) => <String, dynamic>{
  'id': instance.id,
  'sender_id': instance.senderId,
  'body': instance.body,
  'kind': instance.kind,
  'sent_at': instance.sentAt.toIso8601String(),
  'seen_at': instance.seenAt?.toIso8601String(),
  'flagged': instance.flagged,
  'flag_reason': instance.flagReason,
};
