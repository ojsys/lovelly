// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/interest.dart';

part 'interests_client.g.dart';

@RestApi()
abstract class InterestsClient {
  factory InterestsClient(Dio dio, {String? baseUrl}) = _InterestsClient;

  /// The server-controlled interest list (FR-19).
  @GET('/api/v1/interests')
  Future<List<Interest>> interestsList();
}
