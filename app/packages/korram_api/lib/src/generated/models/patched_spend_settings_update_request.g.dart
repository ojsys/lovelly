// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_spend_settings_update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedSpendSettingsUpdateRequest _$PatchedSpendSettingsUpdateRequestFromJson(
  Map<String, dynamic> json,
) => PatchedSpendSettingsUpdateRequest(
  paygEnabled: json['payg_enabled'] as bool?,
  dailyCap: json['daily_cap'] == null
      ? null
      : DailyCapEnum.fromJson((json['daily_cap'] as num).toInt()),
  autoTopup: json['auto_topup'] as bool?,
);

Map<String, dynamic> _$PatchedSpendSettingsUpdateRequestToJson(
  PatchedSpendSettingsUpdateRequest instance,
) => <String, dynamic>{
  'payg_enabled': ?instance.paygEnabled,
  'daily_cap': ?instance.dailyCap,
  'auto_topup': ?instance.autoTopup,
};
