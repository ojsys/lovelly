// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyProfile _$MyProfileFromJson(Map<String, dynamic> json) => MyProfile(
  firstName: json['first_name'] as String,
  age: (json['age'] as num?)?.toInt(),
  city: json['city'] as String,
  state: json['state'] as String,
  bio: json['bio'] as String,
  interests: (json['interests'] as List<dynamic>)
      .map((e) => Interest.fromJson(e as Map<String, dynamic>))
      .toList(),
  languages: (json['languages'] as List<dynamic>).map((e) => e as String).toList(),
  photos: (json['photos'] as List<dynamic>)
      .map((e) => Photo.fromJson(e as Map<String, dynamic>))
      .toList(),
  isVerified: json['is_verified'] as bool,
);

Map<String, dynamic> _$MyProfileToJson(MyProfile instance) => <String, dynamic>{
  'first_name': instance.firstName,
  'age': ?instance.age,
  'city': instance.city,
  'state': instance.state,
  'bio': instance.bio,
  'interests': instance.interests,
  'languages': instance.languages,
  'photos': instance.photos,
  'is_verified': instance.isVerified,
};
