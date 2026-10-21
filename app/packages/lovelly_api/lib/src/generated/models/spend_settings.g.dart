// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spend_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SpendSettings _$SpendSettingsFromJson(Map<String, dynamic> json) => SpendSettings(
  paygEnabled: json['payg_enabled'] as bool,
  dailyCap: DailyCapEnum.fromJson((json['daily_cap'] as num).toInt()),
  autoTopup: json['auto_topup'] as bool,
  topupPack: json['topup_pack'] as String,
  plus: PlusStatus.fromJson(json['plus'] as Map<String, dynamic>),
  prices: Prices.fromJson(json['prices'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SpendSettingsToJson(SpendSettings instance) => <String, dynamic>{
  'payg_enabled': instance.paygEnabled,
  'daily_cap': instance.dailyCap,
  'auto_topup': instance.autoTopup,
  'topup_pack': instance.topupPack,
  'plus': instance.plus,
  'prices': instance.prices,
};
