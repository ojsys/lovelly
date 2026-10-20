// ignore_for_file: unnecessary_cast
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

/// * `purchase` - Coin pack.
/// * `purchase_bonus` - Pack bonus.
/// * `gift` - Gift sent.
/// * `daily_checkin` - Daily check-in.
/// * `invite_reward` - Invite reward.
/// * `refund` - Refund.
@JsonEnum()
enum LedgerReasonEnum {
  @JsonValue('purchase')
  purchase('purchase'),
  @JsonValue('purchase_bonus')
  purchaseBonus('purchase_bonus'),
  @JsonValue('gift')
  gift('gift'),
  @JsonValue('daily_checkin')
  dailyCheckin('daily_checkin'),
  @JsonValue('invite_reward')
  inviteReward('invite_reward'),
  @JsonValue('refund')
  refund('refund'),

  /// Default value for all unparsed values, allows backward compatibility when adding new values on the backend.
  $unknown(null);

  const LedgerReasonEnum(this.json);

  factory LedgerReasonEnum.fromJson(String json) =>
      values.firstWhere((e) => e.json == json, orElse: () => $unknown);

  final String? json;
  String toJson() {
    final value = json;
    if (value == null) {
      throw StateError(
        'Cannot convert enum value with null JSON representation to String. '
        'This usually happens for \$unknown or @JsonValue(null) entries.',
      );
    }
    return value as String;
  }

  @override
  String toString() => json?.toString() ?? super.toString();

  /// Returns all defined enum values excluding the $unknown value.
  static List<LedgerReasonEnum> get $valuesDefined =>
      values.where((value) => value != $unknown).toList();
}
