// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Wallet _$WalletFromJson(Map<String, dynamic> json) => Wallet(
  balance: (json['balance'] as num).toInt(),
  spentToday: (json['spent_today'] as num).toInt(),
  checkin: Checkin.fromJson(json['checkin'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WalletToJson(Wallet instance) => <String, dynamic>{
  'balance': instance.balance,
  'spent_today': instance.spentToday,
  'checkin': instance.checkin,
};
