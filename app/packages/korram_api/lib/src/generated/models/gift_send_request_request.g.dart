// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gift_send_request_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GiftSendRequestRequest _$GiftSendRequestRequestFromJson(Map<String, dynamic> json) =>
    GiftSendRequestRequest(
      gift: json['gift'] as String,
      idempotencyKey: json['idempotency_key'] as String,
    );

Map<String, dynamic> _$GiftSendRequestRequestToJson(GiftSendRequestRequest instance) =>
    <String, dynamic>{'gift': instance.gift, 'idempotency_key': instance.idempotencyKey};
