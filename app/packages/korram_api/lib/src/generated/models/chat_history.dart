// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'chat_message.dart';
import 'friend_summary.dart';

part 'chat_history.g.dart';

@JsonSerializable()
class ChatHistory {
  const ChatHistory({required this.friend, required this.messages, required this.more});

  factory ChatHistory.fromJson(Map<String, Object?> json) => _$ChatHistoryFromJson(json);

  final FriendSummary friend;
  final List<ChatMessage> messages;
  final bool more;

  Map<String, Object?> toJson() => _$ChatHistoryToJson(this);
}
