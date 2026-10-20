// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/gift.dart';

part 'gifts_client.g.dart';

@RestApi()
abstract class GiftsClient {
  factory GiftsClient(Dio dio, {String? baseUrl}) = _GiftsClient;

  @GET('/api/v1/gifts')
  Future<List<Gift>> giftsList();
}
