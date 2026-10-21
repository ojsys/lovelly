// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plus_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlusStatus _$PlusStatusFromJson(Map<String, dynamic> json) => PlusStatus(
  active: json['active'] as bool,
  plan: json['plan'] as String?,
  store: json['store'] as String?,
  periodEnd: json['period_end'] == null ? null : DateTime.parse(json['period_end'] as String),
  autoRenews: json['auto_renews'] as bool,
);

Map<String, dynamic> _$PlusStatusToJson(PlusStatus instance) => <String, dynamic>{
  'active': instance.active,
  'plan': ?instance.plan,
  'store': ?instance.store,
  'period_end': ?instance.periodEnd?.toIso8601String(),
  'auto_renews': instance.autoRenews,
};
