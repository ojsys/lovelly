// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';

import 'clients/auth_client.dart';
import 'clients/blocks_client.dart';
import 'clients/chats_client.dart';
import 'clients/friends_client.dart';
import 'clients/gifts_client.dart';
import 'clients/health_client.dart';
import 'clients/interests_client.dart';
import 'clients/match_client.dart';
import 'clients/me_client.dart';
import 'clients/plus_client.dart';
import 'clients/purchases_client.dart';
import 'clients/reports_client.dart';
import 'clients/sessions_client.dart';
import 'clients/wallet_client.dart';

/// Lovelly API `v1.0.0`
class LovellyApi {
  LovellyApi(Dio dio, {String? baseUrl}) : _dio = dio, _baseUrl = baseUrl;

  final Dio _dio;
  final String? _baseUrl;

  static String get version => '1.0.0';

  AuthClient? _auth;
  BlocksClient? _blocks;
  ChatsClient? _chats;
  FriendsClient? _friends;
  GiftsClient? _gifts;
  HealthClient? _health;
  InterestsClient? _interests;
  MatchClient? _match;
  MeClient? _me;
  PlusClient? _plus;
  PurchasesClient? _purchases;
  ReportsClient? _reports;
  SessionsClient? _sessions;
  WalletClient? _wallet;

  AuthClient get auth => _auth ??= AuthClient(_dio, baseUrl: _baseUrl);

  BlocksClient get blocks => _blocks ??= BlocksClient(_dio, baseUrl: _baseUrl);

  ChatsClient get chats => _chats ??= ChatsClient(_dio, baseUrl: _baseUrl);

  FriendsClient get friends => _friends ??= FriendsClient(_dio, baseUrl: _baseUrl);

  GiftsClient get gifts => _gifts ??= GiftsClient(_dio, baseUrl: _baseUrl);

  HealthClient get health => _health ??= HealthClient(_dio, baseUrl: _baseUrl);

  InterestsClient get interests => _interests ??= InterestsClient(_dio, baseUrl: _baseUrl);

  MatchClient get match => _match ??= MatchClient(_dio, baseUrl: _baseUrl);

  MeClient get me => _me ??= MeClient(_dio, baseUrl: _baseUrl);

  PlusClient get plus => _plus ??= PlusClient(_dio, baseUrl: _baseUrl);

  PurchasesClient get purchases => _purchases ??= PurchasesClient(_dio, baseUrl: _baseUrl);

  ReportsClient get reports => _reports ??= ReportsClient(_dio, baseUrl: _baseUrl);

  SessionsClient get sessions => _sessions ??= SessionsClient(_dio, baseUrl: _baseUrl);

  WalletClient get wallet => _wallet ??= WalletClient(_dio, baseUrl: _baseUrl);
}
