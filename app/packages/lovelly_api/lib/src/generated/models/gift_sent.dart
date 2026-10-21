// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'gift.dart';

part 'gift_sent.g.dart';

@JsonSerializable()
class GiftSent {
  const GiftSent({required this.id, required this.gift, required this.balance});

  factory GiftSent.fromJson(Map<String, Object?> json) => _$GiftSentFromJson(json);

  final String id;
  final Gift gift;
  final int balance;

  Map<String, Object?> toJson() => _$GiftSentToJson(this);
}
