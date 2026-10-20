// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'notice.g.dart';

@JsonSerializable()
class Notice {
  const Notice({required this.id, required this.kind, required this.title, required this.body});

  factory Notice.fromJson(Map<String, Object?> json) => _$NoticeFromJson(json);

  final String id;
  final String kind;
  final String title;
  final String body;

  Map<String, Object?> toJson() => _$NoticeToJson(this);
}
