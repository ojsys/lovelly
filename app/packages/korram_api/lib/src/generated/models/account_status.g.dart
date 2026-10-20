// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountStatus _$AccountStatusFromJson(Map<String, dynamic> json) => AccountStatus(
  status: StatusEnum.fromJson(json['status'] as String),
  suspendedUntil: json['suspended_until'] == null
      ? null
      : DateTime.parse(json['suspended_until'] as String),
  notices: (json['notices'] as List<dynamic>)
      .map((e) => Notice.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AccountStatusToJson(AccountStatus instance) => <String, dynamic>{
  'status': instance.status,
  'suspended_until': instance.suspendedUntil?.toIso8601String(),
  'notices': instance.notices,
};
