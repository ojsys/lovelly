// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'token_refresh.g.dart';

@JsonSerializable()
class TokenRefresh {
  const TokenRefresh({required this.access, required this.refresh});

  factory TokenRefresh.fromJson(Map<String, Object?> json) => _$TokenRefreshFromJson(json);

  final String access;
  final String refresh;

  Map<String, Object?> toJson() => _$TokenRefreshToJson(this);
}
