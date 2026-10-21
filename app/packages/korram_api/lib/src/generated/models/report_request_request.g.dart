// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_request_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReportRequestRequest _$ReportRequestRequestFromJson(Map<String, dynamic> json) =>
    ReportRequestRequest(
      reason: ReasonEnum.fromJson(json['reason'] as String),
      block: json['block'] as bool? ?? true,
      sessionId: json['session_id'] as String?,
      chatId: json['chat_id'] as String?,
    );

Map<String, dynamic> _$ReportRequestRequestToJson(ReportRequestRequest instance) =>
    <String, dynamic>{
      'session_id': ?instance.sessionId,
      'chat_id': ?instance.chatId,
      'reason': instance.reason,
      'block': instance.block,
    };
