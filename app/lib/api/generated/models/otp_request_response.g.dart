// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_request_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpRequestResponse _$OtpRequestResponseFromJson(Map<String, dynamic> json) => OtpRequestResponse(
  phone: json['phone'] as String,
  masked: json['masked'] as String,
  resendIn: (json['resend_in'] as num).toInt(),
);

Map<String, dynamic> _$OtpRequestResponseToJson(OtpRequestResponse instance) => <String, dynamic>{
  'phone': instance.phone,
  'masked': instance.masked,
  'resend_in': instance.resendIn,
};
