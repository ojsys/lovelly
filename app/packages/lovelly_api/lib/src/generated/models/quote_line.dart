// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'quote_line.g.dart';

@JsonSerializable()
class QuoteLine {
  const QuoteLine({required this.kind, required this.cost});

  factory QuoteLine.fromJson(Map<String, Object?> json) => _$QuoteLineFromJson(json);

  /// gender | region | rematch
  final String kind;
  final int cost;

  Map<String, Object?> toJson() => _$QuoteLineToJson(this);
}
