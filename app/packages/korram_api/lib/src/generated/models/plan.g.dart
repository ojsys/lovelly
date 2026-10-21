// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Plan _$PlanFromJson(Map<String, dynamic> json) => Plan(
  plan: PlanEnum.fromJson(json['plan'] as String),
  label: json['label'] as String,
  sub: json['sub'] as String,
  appleProduct: json['apple_product'] as String,
  googleProduct: json['google_product'] as String,
  googleBasePlan: json['google_base_plan'] as String,
);

Map<String, dynamic> _$PlanToJson(Plan instance) => <String, dynamic>{
  'plan': instance.plan,
  'label': instance.label,
  'sub': instance.sub,
  'apple_product': instance.appleProduct,
  'google_product': instance.googleProduct,
  'google_base_plan': instance.googleBasePlan,
};
