// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'store_enum.dart';

part 'purchase_verify_request_request.g.dart';

@JsonSerializable()
class PurchaseVerifyRequestRequest {
  const PurchaseVerifyRequestRequest({
    required this.store,
    required this.productId,
    required this.token,
  });

  factory PurchaseVerifyRequestRequest.fromJson(Map<String, Object?> json) =>
      _$PurchaseVerifyRequestRequestFromJson(json);

  final StoreEnum store;
  @JsonKey(name: 'product_id')
  final String productId;

  /// Google: the purchase token. Apple: the StoreKit 2 signed transaction (JWS).
  final String token;

  Map<String, Object?> toJson() => _$PurchaseVerifyRequestRequestToJson(this);
}
