// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'daily_cap_enum.dart';

part 'patched_spend_settings_update_request.g.dart';

@JsonSerializable()
class PatchedSpendSettingsUpdateRequest {
  const PatchedSpendSettingsUpdateRequest({this.paygEnabled, this.dailyCap, this.autoTopup});

  factory PatchedSpendSettingsUpdateRequest.fromJson(Map<String, Object?> json) =>
      _$PatchedSpendSettingsUpdateRequestFromJson(json);

  @JsonKey(name: 'payg_enabled')
  final bool? paygEnabled;
  @JsonKey(name: 'daily_cap')
  final DailyCapEnum? dailyCap;
  @JsonKey(name: 'auto_topup')
  final bool? autoTopup;

  Map<String, Object?> toJson() => _$PatchedSpendSettingsUpdateRequestToJson(this);
}
