// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'interest.dart';

part 'my_profile.g.dart';

@JsonSerializable()
class MyProfile {
  const MyProfile({
    required this.firstName,
    required this.age,
    required this.city,
    required this.interests,
    required this.languages,
    required this.isVerified,
  });

  factory MyProfile.fromJson(Map<String, Object?> json) => _$MyProfileFromJson(json);

  @JsonKey(name: 'first_name')
  final String firstName;
  final int? age;
  final String city;
  final List<Interest> interests;
  final List<String> languages;
  @JsonKey(name: 'is_verified')
  final bool isVerified;

  Map<String, Object?> toJson() => _$MyProfileToJson(this);
}
