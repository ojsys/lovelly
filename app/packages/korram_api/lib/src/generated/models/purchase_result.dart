// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'purchase_status_enum.dart';

part 'purchase_result.g.dart';

@JsonSerializable()
class PurchaseResult {
  const PurchaseResult({required this.status, required this.balance});

  factory PurchaseResult.fromJson(Map<String, Object?> json) => _$PurchaseResultFromJson(json);

  /// credited: finish the purchase in the store. pending: wait for payment.
  ///
  /// * `pending` - Pending payment.
  /// * `credited` - Credited.
  /// * `refunded` - Refunded.
  final PurchaseStatusEnum status;
  final int balance;

  Map<String, Object?> toJson() => _$PurchaseResultToJson(this);
}
