// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_verify_request_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchaseVerifyRequestRequest _$PurchaseVerifyRequestRequestFromJson(Map<String, dynamic> json) =>
    PurchaseVerifyRequestRequest(
      store: StoreEnum.fromJson(json['store'] as String),
      productId: json['product_id'] as String,
      token: json['token'] as String,
    );

Map<String, dynamic> _$PurchaseVerifyRequestRequestToJson(PurchaseVerifyRequestRequest instance) =>
    <String, dynamic>{
      'store': instance.store,
      'product_id': instance.productId,
      'token': instance.token,
    };
