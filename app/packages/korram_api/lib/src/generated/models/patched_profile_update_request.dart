// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'patched_profile_update_request.g.dart';

/// FR-19 limits are checked in the service layer (accounts.services.profile).
@JsonSerializable()
class PatchedProfileUpdateRequest {
  const PatchedProfileUpdateRequest({
    this.firstName,
    this.bio,
    this.city,
    this.languages,
    this.interests,
    this.photoOrder,
  });

  factory PatchedProfileUpdateRequest.fromJson(Map<String, Object?> json) =>
      _$PatchedProfileUpdateRequestFromJson(json);

  @JsonKey(name: 'first_name')
  final String? firstName;
  final String? bio;
  final String? city;
  final List<String>? languages;
  final List<String>? interests;
  @JsonKey(name: 'photo_order')
  final List<String>? photoOrder;

  Map<String, Object?> toJson() => _$PatchedProfileUpdateRequestToJson(this);
}
