// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendRow _$FriendRowFromJson(Map<String, dynamic> json) => FriendRow(
  chatId: json['chat_id'] as String,
  friend: FriendSummary.fromJson(json['friend'] as Map<String, dynamic>),
  online: json['online'] as bool,
  lastMessage: json['last_message'] == null
      ? null
      : LastMessage.fromJson(json['last_message'] as Map<String, dynamic>),
  unread: (json['unread'] as num).toInt(),
);

Map<String, dynamic> _$FriendRowToJson(FriendRow instance) => <String, dynamic>{
  'chat_id': instance.chatId,
  'friend': instance.friend,
  'online': instance.online,
  'last_message': ?instance.lastMessage,
  'unread': instance.unread,
};
