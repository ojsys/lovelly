// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Session _$SessionFromJson(Map<String, dynamic> json) => Session(
  access: json['access'] as String,
  refresh: json['refresh'] as String,
  nextStep: NextStepEnum.fromJson(json['next_step'] as String),
);

Map<String, dynamic> _$SessionToJson(Session instance) => <String, dynamic>{
  'access': instance.access,
  'refresh': instance.refresh,
  'next_step': instance.nextStep,
};
