// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'media_token.g.dart';

@JsonSerializable()
class MediaToken {
  const MediaToken({required this.mediaToken, required this.mediaUrl});

  factory MediaToken.fromJson(Map<String, Object?> json) => _$MediaTokenFromJson(json);

  @JsonKey(name: 'media_token')
  final String mediaToken;
  @JsonKey(name: 'media_url')
  final String mediaUrl;

  Map<String, Object?> toJson() => _$MediaTokenToJson(this);
}
