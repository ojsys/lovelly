// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gift.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Gift _$GiftFromJson(Map<String, dynamic> json) => Gift(
  slug: json['slug'] as String,
  name: json['name'] as String,
  cost: (json['cost'] as num).toInt(),
);

Map<String, dynamic> _$GiftToJson(Gift instance) => <String, dynamic>{
  'slug': instance.slug,
  'name': instance.name,
  'cost': instance.cost,
};
