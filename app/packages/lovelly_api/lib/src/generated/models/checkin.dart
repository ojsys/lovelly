// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'checkin.g.dart';

@JsonSerializable()
class Checkin {
  const Checkin({required this.claimedToday, required this.day, required this.coins});

  factory Checkin.fromJson(Map<String, Object?> json) => _$CheckinFromJson(json);

  @JsonKey(name: 'claimed_today')
  final bool claimedToday;

  /// Day N of 7 (today's, or the one a claim gives)
  final int day;
  final int coins;

  Map<String, Object?> toJson() => _$CheckinToJson(this);
}
