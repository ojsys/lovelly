// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchaseResult _$PurchaseResultFromJson(Map<String, dynamic> json) => PurchaseResult(
  status: PurchaseStatusEnum.fromJson(json['status'] as String),
  balance: (json['balance'] as num).toInt(),
);

Map<String, dynamic> _$PurchaseResultToJson(PurchaseResult instance) => <String, dynamic>{
  'status': instance.status,
  'balance': instance.balance,
};
