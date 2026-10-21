// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'filter_gender_enum.dart';
import 'filter_region_enum.dart';

part 'filters_request.g.dart';

@JsonSerializable()
class FiltersRequest {
  const FiltersRequest({this.gender, this.region});

  factory FiltersRequest.fromJson(Map<String, Object?> json) => _$FiltersRequestFromJson(json);

  final FilterGenderEnum? gender;
  final FilterRegionEnum? region;

  Map<String, Object?> toJson() => _$FiltersRequestToJson(this);
}
