// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/friend_request.dart';
import '../models/friend_request_create_request.dart';
import '../models/friends.dart';

part 'friends_client.g.dart';

@RestApi()
abstract class FriendsClient {
  factory FriendsClient(Dio dio, {String? baseUrl}) = _FriendsClient;

  @GET('/api/v1/friends')
  Future<Friends> friendsRetrieve();

  @POST('/api/v1/friends/requests')
  Future<FriendRequest> friendsRequestsCreate({@Body() required FriendRequestCreateRequest body});

  @POST('/api/v1/friends/requests/{request_id}/accept')
  Future<FriendRequest> friendsRequestsAcceptCreate({
    @Path('request_id') required String requestId,
  });

  @POST('/api/v1/friends/requests/{request_id}/decline')
  Future<void> friendsRequestsDeclineCreate({@Path('request_id') required String requestId});
}
