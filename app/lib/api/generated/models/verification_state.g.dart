// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verification_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VerificationState _$VerificationStateFromJson(Map<String, dynamic> json) => VerificationState(
  phoneVerified: json['phone_verified'] as bool,
  basicsDone: json['basics_done'] as bool,
  selfie: SelfieEnum.fromJson(json['selfie'] as String),
  attemptsLeft: (json['attempts_left'] as num).toInt(),
  isVerified: json['is_verified'] as bool,
  nextStep: NextStepEnum.fromJson(json['next_step'] as String),
);

Map<String, dynamic> _$VerificationStateToJson(VerificationState instance) => <String, dynamic>{
  'phone_verified': instance.phoneVerified,
  'basics_done': instance.basicsDone,
  'selfie': instance.selfie,
  'attempts_left': instance.attemptsLeft,
  'is_verified': instance.isVerified,
  'next_step': instance.nextStep,
};
