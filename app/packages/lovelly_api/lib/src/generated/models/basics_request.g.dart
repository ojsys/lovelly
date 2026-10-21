// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'basics_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BasicsRequest _$BasicsRequestFromJson(Map<String, dynamic> json) => BasicsRequest(
  firstName: json['first_name'] as String,
  dob: DateTime.parse(json['dob'] as String),
  gender: GenderEnum.fromJson(json['gender'] as String),
  adultConfirmed: json['adult_confirmed'] as bool,
);

Map<String, dynamic> _$BasicsRequestToJson(BasicsRequest instance) => <String, dynamic>{
  'first_name': instance.firstName,
  'dob': instance.dob.toIso8601String(),
  'gender': instance.gender,
  'adult_confirmed': instance.adultConfirmed,
};
