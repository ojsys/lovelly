// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_request_create_request.g.dart';

@JsonSerializable()
class FriendRequestCreateRequest {
  const FriendRequestCreateRequest({required this.sessionId});

  factory FriendRequestCreateRequest.fromJson(Map<String, Object?> json) =>
      _$FriendRequestCreateRequestFromJson(json);

  /// Ask the other person in this session
  @JsonKey(name: 'session_id')
  final String sessionId;

  Map<String, Object?> toJson() => _$FriendRequestCreateRequestToJson(this);
}
