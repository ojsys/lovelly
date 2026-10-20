// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'gift_send_request_request.g.dart';

@JsonSerializable()
class GiftSendRequestRequest {
  const GiftSendRequestRequest({required this.gift, required this.idempotencyKey});

  factory GiftSendRequestRequest.fromJson(Map<String, Object?> json) =>
      _$GiftSendRequestRequestFromJson(json);

  /// Gift slug
  final String gift;

  /// Made once per tap, so a retry never charges twice
  @JsonKey(name: 'idempotency_key')
  final String idempotencyKey;

  Map<String, Object?> toJson() => _$GiftSendRequestRequestToJson(this);
}
