// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Quote _$QuoteFromJson(Map<String, dynamic> json) => Quote(
  lines: (json['lines'] as List<dynamic>)
      .map((e) => QuoteLine.fromJson(e as Map<String, dynamic>))
      .toList(),
  cost: (json['cost'] as num).toInt(),
  freeReason: json['free_reason'] as String?,
  balance: (json['balance'] as num).toInt(),
  available: (json['available'] as num).toInt(),
  spentToday: (json['spent_today'] as num).toInt(),
  dailyCap: (json['daily_cap'] as num).toInt(),
  capLeft: (json['cap_left'] as num?)?.toInt(),
  canPay: json['can_pay'] as bool,
  reason: json['reason'] as String?,
  autoTopup: json['auto_topup'] as bool,
);

Map<String, dynamic> _$QuoteToJson(Quote instance) => <String, dynamic>{
  'lines': instance.lines,
  'cost': instance.cost,
  'free_reason': ?instance.freeReason,
  'balance': instance.balance,
  'available': instance.available,
  'spent_today': instance.spentToday,
  'daily_cap': instance.dailyCap,
  'cap_left': ?instance.capLeft,
  'can_pay': instance.canPay,
  'reason': ?instance.reason,
  'auto_topup': instance.autoTopup,
};
