// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'next_step_enum.dart';
import 'selfie_enum.dart';

part 'verification_state.g.dart';

@JsonSerializable()
class VerificationState {
  const VerificationState({
    required this.phoneVerified,
    required this.basicsDone,
    required this.selfie,
    required this.attemptsLeft,
    required this.isVerified,
    required this.nextStep,
  });

  factory VerificationState.fromJson(Map<String, Object?> json) =>
      _$VerificationStateFromJson(json);

  @JsonKey(name: 'phone_verified')
  final bool phoneVerified;
  @JsonKey(name: 'basics_done')
  final bool basicsDone;
  final SelfieEnum selfie;
  @JsonKey(name: 'attempts_left')
  final int attemptsLeft;
  @JsonKey(name: 'is_verified')
  final bool isVerified;
  @JsonKey(name: 'next_step')
  final NextStepEnum nextStep;

  Map<String, Object?> toJson() => _$VerificationStateToJson(this);
}
