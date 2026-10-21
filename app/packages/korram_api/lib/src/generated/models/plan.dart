// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'plan_enum.dart';

part 'plan.g.dart';

@JsonSerializable()
class Plan {
  const Plan({
    required this.plan,
    required this.label,
    required this.sub,
    required this.appleProduct,
    required this.googleProduct,
    required this.googleBasePlan,
  });

  factory Plan.fromJson(Map<String, Object?> json) => _$PlanFromJson(json);

  final PlanEnum plan;
  final String label;
  final String sub;
  @JsonKey(name: 'apple_product')
  final String appleProduct;
  @JsonKey(name: 'google_product')
  final String googleProduct;
  @JsonKey(name: 'google_base_plan')
  final String googleBasePlan;

  Map<String, Object?> toJson() => _$PlanToJson(this);
}
