// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_request_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendRequestRow _$FriendRequestRowFromJson(Map<String, dynamic> json) => FriendRequestRow(
  id: json['id'] as String,
  sender: FriendSummary.fromJson(json['sender'] as Map<String, dynamic>),
  metOn: json['met_on'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$FriendRequestRowToJson(FriendRequestRow instance) => <String, dynamic>{
  'id': instance.id,
  'sender': instance.sender,
  'met_on': instance.metOn,
  'created_at': instance.createdAt.toIso8601String(),
};
