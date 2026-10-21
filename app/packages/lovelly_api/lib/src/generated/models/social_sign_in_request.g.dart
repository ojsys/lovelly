// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_sign_in_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SocialSignInRequest _$SocialSignInRequestFromJson(Map<String, dynamic> json) => SocialSignInRequest(
  provider: ProviderEnum.fromJson(json['provider'] as String),
  idToken: json['id_token'] as String,
);

Map<String, dynamic> _$SocialSignInRequestToJson(SocialSignInRequest instance) => <String, dynamic>{
  'provider': instance.provider,
  'id_token': instance.idToken,
};
