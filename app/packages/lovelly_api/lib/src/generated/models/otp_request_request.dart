// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'channel_enum.dart';

part 'otp_request_request.g.dart';

@JsonSerializable()
class OtpRequestRequest {
  const OtpRequestRequest({required this.phone, this.channel = ChannelEnum.sms});

  factory OtpRequestRequest.fromJson(Map<String, Object?> json) =>
      _$OtpRequestRequestFromJson(json);

  final String phone;
  final ChannelEnum channel;

  Map<String, Object?> toJson() => _$OtpRequestRequestToJson(this);
}
