// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'gender_enum.dart';

part 'basics_request.g.dart';

@JsonSerializable()
class BasicsRequest {
  const BasicsRequest({
    required this.firstName,
    required this.dob,
    required this.gender,
    required this.adultConfirmed,
  });

  factory BasicsRequest.fromJson(Map<String, Object?> json) => _$BasicsRequestFromJson(json);

  @JsonKey(name: 'first_name')
  final String firstName;
  final DateTime dob;
  final GenderEnum gender;
  @JsonKey(name: 'adult_confirmed')
  final bool adultConfirmed;

  Map<String, Object?> toJson() => _$BasicsRequestToJson(this);
}
