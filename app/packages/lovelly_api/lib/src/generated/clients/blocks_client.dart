// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/block.dart';
import '../models/block_request_request.dart';

part 'blocks_client.g.dart';

@RestApi()
abstract class BlocksClient {
  factory BlocksClient(Dio dio, {String? baseUrl}) = _BlocksClient;

  /// SF-5: block the other person in a session.
  @POST('/api/v1/blocks')
  Future<Block> blocksCreate({@Body() required BlockRequestRequest body});

  @DELETE('/api/v1/blocks/{block_id}')
  Future<void> blocksDestroy({@Path('block_id') required String blockId});
}
