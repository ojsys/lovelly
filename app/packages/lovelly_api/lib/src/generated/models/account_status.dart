// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'notice.dart';
import 'status_enum.dart';

part 'account_status.g.dart';

@JsonSerializable()
class AccountStatus {
  const AccountStatus({required this.status, required this.suspendedUntil, required this.notices});

  factory AccountStatus.fromJson(Map<String, Object?> json) => _$AccountStatusFromJson(json);

  final StatusEnum status;
  @JsonKey(name: 'suspended_until')
  final DateTime? suspendedUntil;
  final List<Notice> notices;

  Map<String, Object?> toJson() => _$AccountStatusToJson(this);
}
