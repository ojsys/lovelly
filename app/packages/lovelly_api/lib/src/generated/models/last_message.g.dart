// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'last_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LastMessage _$LastMessageFromJson(Map<String, dynamic> json) => LastMessage(
  body: json['body'] as String,
  kind: json['kind'] as String,
  mine: json['mine'] as bool,
  sentAt: DateTime.parse(json['sent_at'] as String),
);

Map<String, dynamic> _$LastMessageToJson(LastMessage instance) => <String, dynamic>{
  'body': instance.body,
  'kind': instance.kind,
  'mine': instance.mine,
  'sent_at': instance.sentAt.toIso8601String(),
};
