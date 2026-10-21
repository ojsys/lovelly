// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'rematch.g.dart';

@JsonSerializable()
class Rematch {
  const Rematch({required this.inviteId});

  factory Rematch.fromJson(Map<String, Object?> json) => _$RematchFromJson(json);

  @JsonKey(name: 'invite_id')
  final String inviteId;

  Map<String, Object?> toJson() => _$RematchToJson(this);
}
