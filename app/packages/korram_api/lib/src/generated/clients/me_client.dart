// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/account_status.dart';
import '../models/basics_request.dart';
import '../models/my_profile.dart';
import '../models/verification_state.dart';

part 'me_client.g.dart';

@RestApi()
abstract class MeClient {
  factory MeClient(Dio dio, {String? baseUrl}) = _MeClient;

  @PUT('/api/v1/me/basics')
  Future<VerificationState> meBasicsUpdate({@Body() required BasicsRequest body});

  @POST('/api/v1/me/notices/{notice_id}/seen')
  Future<void> meNoticesSeenCreate({@Path('notice_id') required String noticeId});

  /// Read-only summary for Home and Matching; editing arrives with Profile (M5).
  @GET('/api/v1/me/profile')
  Future<MyProfile> meProfileRetrieve();

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
