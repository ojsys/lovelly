// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gift_sent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GiftSent _$GiftSentFromJson(Map<String, dynamic> json) => GiftSent(
  id: json['id'] as String,
  gift: Gift.fromJson(json['gift'] as Map<String, dynamic>),
  balance: (json['balance'] as num).toInt(),
);

Map<String, dynamic> _$GiftSentToJson(GiftSent instance) => <String, dynamic>{
  'id': instance.id,
  'gift': instance.gift,
  'balance': instance.balance,
};
