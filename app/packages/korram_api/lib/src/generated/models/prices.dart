// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'prices.g.dart';

/// Coins per use (MN-7, 12's pay-as-you-go table). Never hard-coded in the app.
@JsonSerializable()
class Prices {
  const Prices({required this.gender, required this.region, required this.rematch});

  factory Prices.fromJson(Map<String, Object?> json) => _$PricesFromJson(json);

  /// per gender-filtered match that connects
  final int gender;

  /// per region-filtered match that connects
  final int region;

  /// per rematch that connects
  final int rematch;

  Map<String, Object?> toJson() => _$PricesToJson(this);
}
