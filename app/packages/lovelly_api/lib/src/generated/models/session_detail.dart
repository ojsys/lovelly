// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'chat_message.dart';
import 'peer.dart';

part 'session_detail.g.dart';

@JsonSerializable()
class SessionDetail {
  const SessionDetail({
    required this.id,
    required this.mode,
    required this.peer,
    required this.startedAt,
    required this.endedAt,
    required this.endReason,
    required this.messages,
  });

  factory SessionDetail.fromJson(Map<String, Object?> json) => _$SessionDetailFromJson(json);

  final String id;
  final String mode;
  final Peer peer;
  @JsonKey(name: 'started_at')
  final DateTime startedAt;
  @JsonKey(name: 'ended_at')
  final DateTime? endedAt;
  @JsonKey(name: 'end_reason')
  final String endReason;
  final List<ChatMessage> messages;

  Map<String, Object?> toJson() => _$SessionDetailToJson(this);
}
