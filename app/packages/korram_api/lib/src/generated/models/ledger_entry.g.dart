// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LedgerEntry _$LedgerEntryFromJson(Map<String, dynamic> json) => LedgerEntry(
  id: json['id'] as String,
  delta: (json['delta'] as num).toInt(),
  reason: LedgerReasonEnum.fromJson(json['reason'] as String),
  refId: json['ref_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LedgerEntryToJson(LedgerEntry instance) => <String, dynamic>{
  'id': instance.id,
  'delta': instance.delta,
  'reason': instance.reason,
  'ref_id': instance.refId,
  'created_at': instance.createdAt.toIso8601String(),
};
