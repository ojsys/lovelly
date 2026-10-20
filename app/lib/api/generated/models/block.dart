// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'block.g.dart';

@JsonSerializable()
class Block {
  const Block({required this.id});

  factory Block.fromJson(Map<String, Object?> json) => _$BlockFromJson(json);

  final String id;

  Map<String, Object?> toJson() => _$BlockToJson(this);
}
