// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'filters_request.dart';
import 'mode_enum.dart';

part 'quote_request_request.g.dart';

@JsonSerializable()
class QuoteRequestRequest {
  const QuoteRequestRequest({required this.mode, required this.filters});

  factory QuoteRequestRequest.fromJson(Map<String, Object?> json) =>
      _$QuoteRequestRequestFromJson(json);

  final ModeEnum mode;
  final FiltersRequest filters;

  Map<String, Object?> toJson() => _$QuoteRequestRequestToJson(this);
}
