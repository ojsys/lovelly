// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patched_profile_update_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PatchedProfileUpdateRequest _$PatchedProfileUpdateRequestFromJson(Map<String, dynamic> json) =>
    PatchedProfileUpdateRequest(
      firstName: json['first_name'] as String?,
      bio: json['bio'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      languages: (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList(),
      interests: (json['interests'] as List<dynamic>?)?.map((e) => e as String).toList(),
      photoOrder: (json['photo_order'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$PatchedProfileUpdateRequestToJson(PatchedProfileUpdateRequest instance) =>
    <String, dynamic>{
      'first_name': ?instance.firstName,
      'bio': ?instance.bio,
      'city': ?instance.city,
      'state': ?instance.state,
      'languages': ?instance.languages,
      'interests': ?instance.interests,
      'photo_order': ?instance.photoOrder,
    };
