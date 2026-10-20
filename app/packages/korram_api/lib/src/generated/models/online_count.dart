// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'online_count.g.dart';

@JsonSerializable()
class OnlineCount {
  const OnlineCount({required this.count});

  factory OnlineCount.fromJson(Map<String, Object?> json) => _$OnlineCountFromJson(json);

  final int count;

  Map<String, Object?> toJson() => _$OnlineCountToJson(this);
}
