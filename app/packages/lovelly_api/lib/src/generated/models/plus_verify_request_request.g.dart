// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plus_verify_request_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlusVerifyRequestRequest _$PlusVerifyRequestRequestFromJson(Map<String, dynamic> json) =>
    PlusVerifyRequestRequest(
      store: StoreEnum.fromJson(json['store'] as String),
      productId: json['product_id'] as String,
      token: json['token'] as String,
    );

Map<String, dynamic> _$PlusVerifyRequestRequestToJson(PlusVerifyRequestRequest instance) =>
    <String, dynamic>{
      'store': instance.store,
      'product_id': instance.productId,
      'token': instance.token,
    };
