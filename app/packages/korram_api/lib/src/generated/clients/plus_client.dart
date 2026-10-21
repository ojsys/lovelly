// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/plan.dart';
import '../models/plus_status.dart';
import '../models/plus_verify_request_request.dart';

part 'plus_client.g.dart';

@RestApi()
abstract class PlusClient {
  factory PlusClient(Dio dio, {String? baseUrl}) = _PlusClient;

  @GET('/api/v1/plus/plans')
  Future<List<Plan>> plusPlansList();

  /// A Korram Plus purchase or Restore (MN-6).
  @POST('/api/v1/plus/verify')
  Future<PlusStatus> plusVerifyCreate({@Body() required PlusVerifyRequestRequest body});
}
