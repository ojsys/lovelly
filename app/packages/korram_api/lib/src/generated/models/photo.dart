// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'photo.g.dart';

@JsonSerializable()
class Photo {
  const Photo({required this.id, required this.url});

  factory Photo.fromJson(Map<String, Object?> json) => _$PhotoFromJson(json);

  final String id;
  final String url;

  Map<String, Object?> toJson() => _$PhotoToJson(this);
}
