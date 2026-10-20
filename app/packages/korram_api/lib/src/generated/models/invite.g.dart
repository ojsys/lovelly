// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Invite _$InviteFromJson(Map<String, dynamic> json) => Invite(
  code: json['code'] as String,
  link: json['link'] as String,
  coins: (json['coins'] as num).toInt(),
  rewarded: (json['rewarded'] as num).toInt(),
);

Map<String, dynamic> _$InviteToJson(Invite instance) => <String, dynamic>{
  'code': instance.code,
  'link': instance.link,
  'coins': instance.coins,
  'rewarded': instance.rewarded,
};
