// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Checkin _$CheckinFromJson(Map<String, dynamic> json) => Checkin(
  claimedToday: json['claimed_today'] as bool,
  day: (json['day'] as num).toInt(),
  coins: (json['coins'] as num).toInt(),
);

Map<String, dynamic> _$CheckinToJson(Checkin instance) => <String, dynamic>{
  'claimed_today': instance.claimedToday,
  'day': instance.day,
  'coins': instance.coins,
};
