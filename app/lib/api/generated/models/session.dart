// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'next_step_enum.dart';

part 'session.g.dart';

@JsonSerializable()
class Session {
  const Session({required this.access, required this.refresh, required this.nextStep});

  factory Session.fromJson(Map<String, Object?> json) => _$SessionFromJson(json);

  final String access;
  final String refresh;
  @JsonKey(name: 'next_step')
  final NextStepEnum nextStep;

  Map<String, Object?> toJson() => _$SessionToJson(this);
}
