// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionDetail _$SessionDetailFromJson(Map<String, dynamic> json) => SessionDetail(
  id: json['id'] as String,
  mode: json['mode'] as String,
  peer: Peer.fromJson(json['peer'] as Map<String, dynamic>),
  startedAt: DateTime.parse(json['started_at'] as String),
  endedAt: json['ended_at'] == null ? null : DateTime.parse(json['ended_at'] as String),
  endReason: json['end_reason'] as String,
  messages: (json['messages'] as List<dynamic>)
      .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SessionDetailToJson(SessionDetail instance) => <String, dynamic>{
  'id': instance.id,
  'mode': instance.mode,
  'peer': instance.peer,
  'started_at': instance.startedAt.toIso8601String(),
  'ended_at': ?instance.endedAt?.toIso8601String(),
  'end_reason': instance.endReason,
  'messages': instance.messages,
};
