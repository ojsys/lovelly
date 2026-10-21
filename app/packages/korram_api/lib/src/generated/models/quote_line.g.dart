// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote_line.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuoteLine _$QuoteLineFromJson(Map<String, dynamic> json) =>
    QuoteLine(kind: json['kind'] as String, cost: (json['cost'] as num).toInt());

Map<String, dynamic> _$QuoteLineToJson(QuoteLine instance) => <String, dynamic>{
  'kind': instance.kind,
  'cost': instance.cost,
};
