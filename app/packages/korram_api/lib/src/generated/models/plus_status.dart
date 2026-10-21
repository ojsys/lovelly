// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'plus_status.g.dart';

@JsonSerializable()
class PlusStatus {
  const PlusStatus({
    required this.active,
    required this.plan,
    required this.store,
    required this.periodEnd,
    required this.autoRenews,
  });

  factory PlusStatus.fromJson(Map<String, Object?> json) => _$PlusStatusFromJson(json);

  final bool active;
  final String? plan;
  final String? store;
  @JsonKey(name: 'period_end')
  final DateTime? periodEnd;
  @JsonKey(name: 'auto_renews')
  final bool autoRenews;

  Map<String, Object?> toJson() => _$PlusStatusToJson(this);
}
