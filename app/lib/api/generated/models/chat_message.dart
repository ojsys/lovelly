// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

@JsonSerializable()
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.kind,
    required this.sentAt,
    required this.seenAt,
    required this.flagged,
    required this.flagReason,
  });

  factory ChatMessage.fromJson(Map<String, Object?> json) => _$ChatMessageFromJson(json);

  final String id;
  @JsonKey(name: 'sender_id')
  final String senderId;
  final String body;
  final String kind;
  @JsonKey(name: 'sent_at')
  final DateTime sentAt;
  @JsonKey(name: 'seen_at')
  final DateTime? seenAt;
  final bool flagged;
  @JsonKey(name: 'flag_reason')
  final String flagReason;

  Map<String, Object?> toJson() => _$ChatMessageToJson(this);
}
