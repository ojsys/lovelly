// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_summary.g.dart';

@JsonSerializable()
class FriendSummary {
  const FriendSummary({
    required this.firstName,
    required this.age,
    required this.city,
    required this.verified,
    required this.photoUrl,
  });

  factory FriendSummary.fromJson(Map<String, Object?> json) => _$FriendSummaryFromJson(json);

  @JsonKey(name: 'first_name')
  final String firstName;
  final int? age;
  final String city;
  final bool verified;
  @JsonKey(name: 'photo_url')
  final String? photoUrl;

  Map<String, Object?> toJson() => _$FriendSummaryToJson(this);
}
