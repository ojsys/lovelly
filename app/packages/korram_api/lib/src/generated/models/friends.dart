// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'friend_request_row.dart';
import 'friend_row.dart';

part 'friends.g.dart';

@JsonSerializable()
class Friends {
  const Friends({required this.friends, required this.requests});

  factory Friends.fromJson(Map<String, Object?> json) => _$FriendsFromJson(json);

  final List<FriendRow> friends;
  final List<FriendRequestRow> requests;

  Map<String, Object?> toJson() => _$FriendsToJson(this);
}
