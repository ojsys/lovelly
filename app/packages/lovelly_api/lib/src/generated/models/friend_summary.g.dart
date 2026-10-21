// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendSummary _$FriendSummaryFromJson(Map<String, dynamic> json) => FriendSummary(
  firstName: json['first_name'] as String,
  age: (json['age'] as num?)?.toInt(),
  city: json['city'] as String,
  verified: json['verified'] as bool,
  photoUrl: json['photo_url'] as String?,
);

Map<String, dynamic> _$FriendSummaryToJson(FriendSummary instance) => <String, dynamic>{
  'first_name': instance.firstName,
  'age': ?instance.age,
  'city': instance.city,
  'verified': instance.verified,
  'photo_url': ?instance.photoUrl,
};
