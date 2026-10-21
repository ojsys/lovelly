// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pack.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pack _$PackFromJson(Map<String, dynamic> json) => Pack(
  productId: json['product_id'] as String,
  coins: (json['coins'] as num).toInt(),
  bonus: (json['bonus'] as num).toInt(),
  label: json['label'] as String,
  tag: json['tag'] as String,
);

Map<String, dynamic> _$PackToJson(Pack instance) => <String, dynamic>{
  'product_id': instance.productId,
  'coins': instance.coins,
  'bonus': instance.bonus,
  'label': instance.label,
  'tag': instance.tag,
};
