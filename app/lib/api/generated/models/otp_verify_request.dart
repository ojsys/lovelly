// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'otp_verify_request.g.dart';

@JsonSerializable()
class OtpVerifyRequest {
  const OtpVerifyRequest({required this.phone, required this.code});

  factory OtpVerifyRequest.fromJson(Map<String, Object?> json) => _$OtpVerifyRequestFromJson(json);

  final String phone;
  final String code;

  Map<String, Object?> toJson() => _$OtpVerifyRequestToJson(this);
}
