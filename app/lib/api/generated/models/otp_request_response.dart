// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'otp_request_response.g.dart';

@JsonSerializable()
class OtpRequestResponse {
  const OtpRequestResponse({required this.phone, required this.masked, required this.resendIn});

  factory OtpRequestResponse.fromJson(Map<String, Object?> json) =>
      _$OtpRequestResponseFromJson(json);

  /// E.164 form of the number
  final String phone;

  /// e.g. +234 803 ••• ••42
  final String masked;

  /// Seconds until another code may be sent
  @JsonKey(name: 'resend_in')
  final int resendIn;

  Map<String, Object?> toJson() => _$OtpRequestResponseToJson(this);
}
