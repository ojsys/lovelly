// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'friend_summary.dart';

part 'friend_request_row.g.dart';

@JsonSerializable()
class FriendRequestRow {
  const FriendRequestRow({
    required this.id,
    required this.sender,
    required this.metOn,
    required this.createdAt,
  });

  factory FriendRequestRow.fromJson(Map<String, Object?> json) => _$FriendRequestRowFromJson(json);

  final String id;
  final FriendSummary sender;
  @JsonKey(name: 'met_on')
  final String? metOn;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  Map<String, Object?> toJson() => _$FriendRequestRowToJson(this);
}
