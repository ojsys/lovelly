import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';

/// Friends, friend chats and the profile (FR-16, FR-19). Errors surface as [ApiFailure].
class FriendsRepository {
  FriendsRepository(this._api);

  final LovellyApi _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<Friends> friends() => _call(() => _api.friends.friendsRetrieve());

  Future<void> request(String sessionId) => _call(
    () =>
        _api.friends.friendsRequestsCreate(body: FriendRequestCreateRequest(sessionId: sessionId)),
  );

  Future<void> accept(String requestId) =>
      _call(() => _api.friends.friendsRequestsAcceptCreate(requestId: requestId));

  Future<void> decline(String requestId) =>
      _call(() => _api.friends.friendsRequestsDeclineCreate(requestId: requestId));

  Future<ChatHistory> history(String chatId, {String? before}) =>
      _call(() => _api.chats.chatsMessagesRetrieve(chatId: chatId, before: before));

  Future<MyProfile> profile() => _call(() => _api.me.meProfileRetrieve());

  Future<MyProfile> updateProfile(PatchedProfileUpdateRequest body) =>
      _call(() => _api.me.meProfilePartialUpdate(body: body));

  Future<MyProfile> addPhoto(String path) => _call(() => _api.me.mePhotosCreate(photo: File(path)));

  Future<MyProfile> deletePhoto(String id) => _call(() => _api.me.mePhotosDestroy(photoId: id));

  Future<List<Interest>> interests() => _call(() => _api.interests.interestsList());

  Future<void> registerDevice(String platform, String token) => _call(
    () => _api.me.meDevicesCreate(
      body: DeviceRequest(
        platform: platform == 'ios' ? PlatformEnum.ios : PlatformEnum.android,
        fcmToken: token,
      ),
    ),
  );
}

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(ref.watch(apiProvider)),
);
