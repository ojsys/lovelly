// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'quote_line.dart';

part 'quote.g.dart';

@JsonSerializable()
class Quote {
  const Quote({
    required this.lines,
    required this.cost,
    required this.freeReason,
    required this.balance,
    required this.available,
    required this.spentToday,
    required this.dailyCap,
    required this.capLeft,
    required this.canPay,
    required this.reason,
    required this.autoTopup,
  });

  factory Quote.fromJson(Map<String, Object?> json) => _$QuoteFromJson(json);

  final List<QuoteLine> lines;

  /// Coins taken when the match has run 5 s
  final int cost;

  /// plus | no_filters
  @JsonKey(name: 'free_reason')
  final String? freeReason;
  final int balance;

  /// Balance minus coins on hold
  final int available;
  @JsonKey(name: 'spent_today')
  final int spentToday;

  /// 0 = no cap
  @JsonKey(name: 'daily_cap')
  final int dailyCap;
  @JsonKey(name: 'cap_left')
  final int? capLeft;
  @JsonKey(name: 'can_pay')
  final bool canPay;

  /// payg_off | cap_reached | low_balance
  final String? reason;
  @JsonKey(name: 'auto_topup')
  final bool autoTopup;

  Map<String, Object?> toJson() => _$QuoteToJson(this);
}
