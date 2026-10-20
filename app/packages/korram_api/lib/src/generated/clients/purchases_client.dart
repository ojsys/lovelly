// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/purchase_result.dart';
import '../models/purchase_verify_request_request.dart';

part 'purchases_client.g.dart';

@RestApi()
abstract class PurchasesClient {
  factory PurchasesClient(Dio dio, {String? baseUrl}) = _PurchasesClient;

  @POST('/api/v1/purchases/verify')
  Future<PurchaseResult> purchasesVerifyCreate({
    @Body() required PurchaseVerifyRequestRequest body,
  });
}
