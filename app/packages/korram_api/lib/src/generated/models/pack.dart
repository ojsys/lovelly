// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pack.g.dart';

@JsonSerializable()
class Pack {
  const Pack({
    required this.productId,
    required this.coins,
    required this.bonus,
    required this.label,
    required this.tag,
  });

  factory Pack.fromJson(Map<String, Object?> json) => _$PackFromJson(json);

  /// The store product id; the price comes from the store
  @JsonKey(name: 'product_id')
  final String productId;

  /// Total coins, bonus included
  final int coins;
  final int bonus;
  final String label;
  final String tag;

  Map<String, Object?> toJson() => _$PackToJson(this);
}
