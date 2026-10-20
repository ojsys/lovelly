// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Ledger _$LedgerFromJson(Map<String, dynamic> json) => Ledger(
  entries: (json['entries'] as List<dynamic>)
      .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
      .toList(),
  more: json['more'] as bool,
);

Map<String, dynamic> _$LedgerToJson(Ledger instance) => <String, dynamic>{
  'entries': instance.entries,
  'more': instance.more,
};
