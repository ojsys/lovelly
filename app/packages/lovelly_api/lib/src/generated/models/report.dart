// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'report.g.dart';

@JsonSerializable()
class Report {
  const Report({required this.id, required this.blocked});

  factory Report.fromJson(Map<String, Object?> json) => _$ReportFromJson(json);

  final String id;
  final bool blocked;

  Map<String, Object?> toJson() => _$ReportToJson(this);
}
