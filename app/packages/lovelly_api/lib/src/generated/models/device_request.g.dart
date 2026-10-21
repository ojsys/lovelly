// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceRequest _$DeviceRequestFromJson(Map<String, dynamic> json) => DeviceRequest(
  platform: PlatformEnum.fromJson(json['platform'] as String),
  fcmToken: json['fcm_token'] as String,
);

Map<String, dynamic> _$DeviceRequestToJson(DeviceRequest instance) => <String, dynamic>{
  'platform': instance.platform,
  'fcm_token': instance.fcmToken,
};
