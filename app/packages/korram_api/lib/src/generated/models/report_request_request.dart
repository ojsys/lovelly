// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'reason_enum.dart';

part 'report_request_request.g.dart';

@JsonSerializable()
class ReportRequestRequest {
  const ReportRequestRequest({required this.sessionId, required this.reason, this.block = true});

  factory ReportRequestRequest.fromJson(Map<String, Object?> json) =>
      _$ReportRequestRequestFromJson(json);

  @JsonKey(name: 'session_id')
  final String sessionId;
  final ReasonEnum reason;
  final bool block;

  Map<String, Object?> toJson() => _$ReportRequestRequestToJson(this);
}
