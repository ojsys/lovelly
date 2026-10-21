// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'interest.g.dart';

@JsonSerializable()
class Interest {
  const Interest({required this.slug, required this.label});

  factory Interest.fromJson(Map<String, Object?> json) => _$InterestFromJson(json);

  final String slug;
  final String label;

  Map<String, Object?> toJson() => _$InterestToJson(this);
}
