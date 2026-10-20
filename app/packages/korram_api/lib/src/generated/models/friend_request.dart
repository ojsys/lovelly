// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_request.g.dart';

@JsonSerializable()
class FriendRequest {
  const FriendRequest({required this.id, required this.status});

  factory FriendRequest.fromJson(Map<String, Object?> json) => _$FriendRequestFromJson(json);

  final String id;
  final String status;

  Map<String, Object?> toJson() => _$FriendRequestToJson(this);
}
