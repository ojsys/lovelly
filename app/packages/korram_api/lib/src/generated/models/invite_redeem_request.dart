// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'invite_redeem_request.g.dart';

@JsonSerializable()
class InviteRedeemRequest {
  const InviteRedeemRequest({required this.code});

  factory InviteRedeemRequest.fromJson(Map<String, Object?> json) =>
      _$InviteRedeemRequestFromJson(json);

  final String code;

  Map<String, Object?> toJson() => _$InviteRedeemRequestToJson(this);
}
