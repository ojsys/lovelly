// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/chat_history.dart';
import '../models/gift_send_request_request.dart';
import '../models/gift_sent.dart';

part 'chats_client.g.dart';

@RestApi()
abstract class ChatsClient {
  factory ChatsClient(Dio dio, {String? baseUrl}) = _ChatsClient;

  @POST('/api/v1/chats/{chat_id}/gifts')
  Future<GiftSent> chatsGiftsCreate({
    @Path('chat_id') required String chatId,
    @Body() required GiftSendRequestRequest body,
  });

  /// FR-15: saved history with a friend, newest first; `before` pages back.
  ///
  /// [before] - ISO time: older than this.
  @GET('/api/v1/chats/{chat_id}/messages')
  Future<ChatHistory> chatsMessagesRetrieve({
    @Path('chat_id') required String chatId,
    @Query('before') String? before,
  });
}
