// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'last_message.g.dart';

@JsonSerializable()
class LastMessage {
  const LastMessage({
    required this.body,
    required this.kind,
    required this.mine,
    required this.sentAt,
  });

  factory LastMessage.fromJson(Map<String, Object?> json) => _$LastMessageFromJson(json);

  final String body;
  final String kind;
  final bool mine;
  @JsonKey(name: 'sent_at')
  final DateTime sentAt;

  Map<String, Object?> toJson() => _$LastMessageToJson(this);
}
