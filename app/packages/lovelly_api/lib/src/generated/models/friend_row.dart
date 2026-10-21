// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'friend_summary.dart';
import 'last_message.dart';

part 'friend_row.g.dart';

@JsonSerializable()
class FriendRow {
  const FriendRow({
    required this.chatId,
    required this.friend,
    required this.online,
    required this.lastMessage,
    required this.unread,
  });

  factory FriendRow.fromJson(Map<String, Object?> json) => _$FriendRowFromJson(json);

  @JsonKey(name: 'chat_id')
  final String chatId;
  final FriendSummary friend;
  final bool online;
  @JsonKey(name: 'last_message')
  final LastMessage? lastMessage;
  final int unread;

  Map<String, Object?> toJson() => _$FriendRowToJson(this);
}
