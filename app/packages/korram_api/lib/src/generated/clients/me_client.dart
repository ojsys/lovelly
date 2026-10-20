// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/account_status.dart';
import '../models/basics_request.dart';
import '../models/device_request.dart';
import '../models/my_profile.dart';
import '../models/patched_profile_update_request.dart';
import '../models/verification_state.dart';

part 'me_client.g.dart';

@RestApi()
abstract class MeClient {
  factory MeClient(Dio dio, {String? baseUrl}) = _MeClient;

  @PUT('/api/v1/me/basics')
  Future<VerificationState> meBasicsUpdate({@Body() required BasicsRequest body});

  /// FR-17: register (or move) this install's push token.
  @POST('/api/v1/me/devices')
  Future<void> meDevicesCreate({@Body() required DeviceRequest body});

  /// Sign-out: stop pushes to this install.
  @DELETE('/api/v1/me/devices')
  Future<void> meDevicesDestroy({@Query('fcm_token') required String fcmToken});

  @POST('/api/v1/me/notices/{notice_id}/seen')
  Future<void> meNoticesSeenCreate({@Path('notice_id') required String noticeId});

  @MultiPart()
  @POST('/api/v1/me/photos')
  Future<MyProfile> mePhotosCreate({@Part(name: 'photo') required File photo});

  @DELETE('/api/v1/me/photos/{photo_id}')
  Future<MyProfile> mePhotosDestroy({@Path('photo_id') required String photoId});

  /// FR-19: the signed-in user's profile.
  @GET('/api/v1/me/profile')
  Future<MyProfile> meProfileRetrieve();

  /// FR-19: the signed-in user's profile.
  @PATCH('/api/v1/me/profile')
  Future<MyProfile> meProfilePartialUpdate({@Body() PatchedProfileUpdateRequest? body});

  @MultiPart()
  @POST('/api/v1/me/selfie')
  Future<VerificationState> meSelfieCreate({
    @Part(name: 'pose_front') required File poseFront,
    @Part(name: 'pose_left') required File poseLeft,
  });

  /// Suspension and unseen notices (warnings) for the app (SF-6).
  @GET('/api/v1/me/status')
  Future<AccountStatus> meStatusRetrieve();

  @GET('/api/v1/me/verification')
  Future<VerificationState> meVerificationRetrieve();
}
