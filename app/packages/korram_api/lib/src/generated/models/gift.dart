// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'gift.g.dart';

@JsonSerializable()
class Gift {
  const Gift({required this.slug, required this.name, required this.cost});

  factory Gift.fromJson(Map<String, Object?> json) => _$GiftFromJson(json);

  final String slug;
  final String name;
  final int cost;

  Map<String, Object?> toJson() => _$GiftToJson(this);
}
