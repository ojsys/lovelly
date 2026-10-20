// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'checkin.dart';

part 'wallet.g.dart';

@JsonSerializable()
class Wallet {
  const Wallet({required this.balance, required this.spentToday, required this.checkin});

  factory Wallet.fromJson(Map<String, Object?> json) => _$WalletFromJson(json);

  final int balance;
  @JsonKey(name: 'spent_today')
  final int spentToday;
  final Checkin checkin;

  Map<String, Object?> toJson() => _$WalletToJson(this);
}
