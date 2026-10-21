// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prices.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Prices _$PricesFromJson(Map<String, dynamic> json) => Prices(
  gender: (json['gender'] as num).toInt(),
  region: (json['region'] as num).toInt(),
  rematch: (json['rematch'] as num).toInt(),
);

Map<String, dynamic> _$PricesToJson(Prices instance) => <String, dynamic>{
  'gender': instance.gender,
  'region': instance.region,
  'rematch': instance.rematch,
};
