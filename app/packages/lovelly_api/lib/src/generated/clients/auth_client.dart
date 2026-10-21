// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/otp_request_request.dart';
import '../models/otp_request_response.dart';
import '../models/otp_verify_request.dart';
import '../models/session.dart';
import '../models/social_sign_in_request.dart';
import '../models/token_refresh.dart';
import '../models/token_refresh_request.dart';

part 'auth_client.g.dart';

@RestApi()
abstract class AuthClient {
  factory AuthClient(Dio dio, {String? baseUrl}) = _AuthClient;

  /// FR-1: text or call a 6-digit code. Signed-in Google/Apple users use this too (FR-2).
  @POST('/api/v1/auth/otp/request')
  Future<OtpRequestResponse> authOtpRequestCreate({@Body() required OtpRequestRequest body});

  @POST('/api/v1/auth/otp/verify')
  Future<Session> authOtpVerifyCreate({@Body() required OtpVerifyRequest body});

  /// Takes a refresh type JSON web token and returns an access type JSON web.
  /// token if the refresh token is valid.
  @POST('/api/v1/auth/refresh')
  Future<TokenRefresh> authRefreshCreate({@Body() required TokenRefreshRequest body});

  @POST('/api/v1/auth/social')
  Future<Session> authSocialCreate({@Body() required SocialSignInRequest body});
}
