// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'provider_enum.dart';

part 'social_sign_in_request.g.dart';

@JsonSerializable()
class SocialSignInRequest {
  const SocialSignInRequest({required this.provider, required this.idToken});

  factory SocialSignInRequest.fromJson(Map<String, Object?> json) =>
      _$SocialSignInRequestFromJson(json);

  final ProviderEnum provider;
  @JsonKey(name: 'id_token')
  final String idToken;

  Map<String, Object?> toJson() => _$SocialSignInRequestToJson(this);
}
