// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filters_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FiltersRequest _$FiltersRequestFromJson(Map<String, dynamic> json) => FiltersRequest(
  gender: json['gender'] == null ? null : FilterGenderEnum.fromJson(json['gender'] as String),
  region: json['region'] == null ? null : FilterRegionEnum.fromJson(json['region'] as String),
);

Map<String, dynamic> _$FiltersRequestToJson(FiltersRequest instance) => <String, dynamic>{
  'gender': ?instance.gender,
  'region': ?instance.region,
};
