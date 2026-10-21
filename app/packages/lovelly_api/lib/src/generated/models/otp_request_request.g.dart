// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_request_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpRequestRequest _$OtpRequestRequestFromJson(Map<String, dynamic> json) => OtpRequestRequest(
  phone: json['phone'] as String,
  channel: json['channel'] == null
      ? ChannelEnum.sms
      : ChannelEnum.fromJson(json['channel'] as String),
);

Map<String, dynamic> _$OtpRequestRequestToJson(OtpRequestRequest instance) => <String, dynamic>{
  'phone': instance.phone,
  'channel': instance.channel,
};
