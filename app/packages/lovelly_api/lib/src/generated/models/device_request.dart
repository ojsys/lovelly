// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'platform_enum.dart';

part 'device_request.g.dart';

@JsonSerializable()
class DeviceRequest {
  const DeviceRequest({required this.platform, required this.fcmToken});

  factory DeviceRequest.fromJson(Map<String, Object?> json) => _$DeviceRequestFromJson(json);

  final PlatformEnum platform;
  @JsonKey(name: 'fcm_token')
  final String fcmToken;

  Map<String, Object?> toJson() => _$DeviceRequestToJson(this);
}
