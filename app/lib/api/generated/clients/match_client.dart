// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/online_count.dart';

part 'match_client.g.dart';

@RestApi()
abstract class MatchClient {
  factory MatchClient(Dio dio, {String? baseUrl}) = _MatchClient;

  /// FR-9: live count of people online.
  @GET('/api/v1/match/online-count')
  Future<OnlineCount> matchOnlineCountRetrieve();
}
