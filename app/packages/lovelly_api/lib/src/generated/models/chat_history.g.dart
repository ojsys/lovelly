// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatHistory _$ChatHistoryFromJson(Map<String, dynamic> json) => ChatHistory(
  friend: FriendSummary.fromJson(json['friend'] as Map<String, dynamic>),
  messages: (json['messages'] as List<dynamic>)
      .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
      .toList(),
  more: json['more'] as bool,
);

Map<String, dynamic> _$ChatHistoryToJson(ChatHistory instance) => <String, dynamic>{
  'friend': instance.friend,
  'messages': instance.messages,
  'more': instance.more,
};
